"""Auth middleware — JWT validation, user lookup, Redis caching.

B2C tokens are RS256 JWTs. Validation flow:
  1. Extract Bearer token from Authorization header.
  2. Fetch B2C JWKS (cached in Redis for 24 h) and verify signature.
  3. Extract b2c_object_id (sub claim) and look up the User document.
  4. Cache the User document in Redis for 5 minutes to avoid Cosmos round-trips.
  5. Attach the User to request state for downstream handlers.
"""

import json
import logging
from typing import Any

import httpx
from fastapi import Depends, Request
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from jose import JWTError, jwt

from uuid import uuid4
from app.core.config import settings
from app.core.database import USERS, WORKSPACES, get_collection
from app.core.exceptions import ForbiddenError, UnauthorizedError
from app.core.redis_client import get_redis
from app.models.user import User, UserRole, WorkspaceMembership
from app.models.workspace import Workspace
from app.models.base import utc_now

logger = logging.getLogger(__name__)

_bearer = HTTPBearer(auto_error=False)

# Redis TTLs
_JWKS_TTL_SECONDS = 86_400   # 24 h — JWKS rotates infrequently
_USER_TTL_SECONDS = 300       # 5 min — role/membership changes should propagate quickly


def _jwks_url() -> str:
    """Return the JWKS endpoint for our Entra External ID (CIAM) tenant.

    Project is on Entra External ID, not classic B2C — the URL form is
    ``{subdomain}.ciamlogin.com/{tenant_guid}/discovery/v2.0/keys``.
    """
    subdomain = settings.b2c_tenant_subdomain or settings.b2c_tenant_id
    return (
        f"https://{subdomain}.ciamlogin.com/"
        f"{settings.b2c_tenant_id}/discovery/v2.0/keys"
    )


async def _get_jwks() -> dict[str, Any]:
    """Fetch JWKS from B2C, cached in Redis."""
    redis = await get_redis()
    cached = await redis.get("b2c:jwks")
    if cached:
        return json.loads(cached)  # type: ignore[no-any-return]

    async with httpx.AsyncClient() as client:
        response = await client.get(_jwks_url(), timeout=10)
        response.raise_for_status()
        jwks = response.json()

    await redis.setex("b2c:jwks", _JWKS_TTL_SECONDS, json.dumps(jwks))
    return jwks  # type: ignore[no-any-return]


async def _get_google_jwks() -> dict[str, Any]:
    """Fetch JWKS from Google, cached in Redis."""
    redis = await get_redis()
    cached = await redis.get("google:jwks")
    if cached:
        return json.loads(cached)  # type: ignore[no-any-return]

    async with httpx.AsyncClient() as client:
        response = await client.get("https://www.googleapis.com/oauth2/v3/certs", timeout=10)
        response.raise_for_status()
        jwks = response.json()

    await redis.setex("google:jwks", _JWKS_TTL_SECONDS, json.dumps(jwks))
    return jwks  # type: ignore[no-any-return]


async def _validate_token(token: str) -> dict[str, Any]:
    """Validate a JWT token (either Azure AD B2C or Google OAuth2 ID Token) and return its claims."""
    try:
        try:
            unverified_claims = jwt.get_unverified_claims(token)
            iss = unverified_claims.get("iss", "")
        except Exception:
            iss = ""

        if "accounts.google.com" in iss:
            # Google ID Token validation
            jwks = await _get_google_jwks()
            claims = jwt.decode(
                token,
                jwks,
                algorithms=["RS256"],
                options={"verify_at_hash": False, "verify_aud": False},
            )
            return claims
        else:
            # Azure AD B2C RS256 validation
            jwks = await _get_jwks()
            claims = jwt.decode(
                token,
                jwks,
                algorithms=["RS256"],
                audience=settings.b2c_client_id,
                options={"verify_at_hash": False},
            )
            return claims
    except JWTError as exc:
        raise UnauthorizedError(f"Invalid token: {exc}") from exc


async def _lookup_or_create_user(b2c_object_id: str, tenant_id: str, claims: dict[str, Any]) -> User:
    """Look up the User document, or auto-create/provision it if it doesn't exist."""
    redis = await get_redis()
    cache_key = f"user:{tenant_id}:{b2c_object_id}"

    cached = await redis.get(cache_key)
    if cached:
        return User.model_validate_json(cached)

    collection = get_collection(tenant_id, USERS)
    doc = await collection.find_one({"b2c_object_id": b2c_object_id, "deleted_at": None})
    if doc is None:
        # Check if the user was invited by an admin using their email
        # The email claim is extracted below, but we need it here
        _PLACEHOLDER_EMAIL = "user@socialstudyapp.com"
        real_email: str = (
            claims.get("email")
            or claims.get("preferred_username")
            or claims.get("unique_name")
            or claims.get("upn")
            or (claims["emails"][0] if isinstance(claims.get("emails"), list) and claims["emails"] else None)
            or claims.get("emails")
            or _PLACEHOLDER_EMAIL
        )
        if isinstance(real_email, str):
            real_email = real_email.split("?")[0].strip().lower()
            
        doc = await collection.find_one({"email": real_email, "deleted_at": None})
        if doc is not None:
            # Found the invited user, link their b2c_object_id
            await collection.update_one({"_id": doc["_id"]}, {"$set": {"b2c_object_id": b2c_object_id}})
            doc["b2c_object_id"] = b2c_object_id


    # --- Extract real values from token claims ----------------------------
    # Entra External ID (CIAM) may put the email in any of these claims
    # depending on the user-flow configuration. Try them all, most-specific first.
    _PLACEHOLDER_EMAIL = "user@socialstudyapp.com"
    real_email: str = (
        claims.get("email")
        or claims.get("preferred_username")   # Entra External ID default
        or claims.get("unique_name")          # classic B2C / AAD
        or claims.get("upn")                  # enterprise fallback
        or (
            claims["emails"][0]
            if isinstance(claims.get("emails"), list) and claims["emails"]
            else None
        )
        or claims.get("emails")               # sometimes a bare string
        or _PLACEHOLDER_EMAIL
    )
    # Strip any query-string suffix that CIAM sometimes appends to preferred_username
    real_email = real_email.split("?")[0].strip()

    given_name = claims.get("given_name") or claims.get("givenName")
    family_name = claims.get("family_name") or claims.get("surname")
    is_google_identity = "accounts.google.com" in str(claims.get("iss", ""))
    # The student UI greets people by their given name. Google reliably sends
    # that value separately, so retain it instead of persisting an email-style
    # account label (for example ``tarunjuneja471``) or a full legal name.
    if is_google_identity and given_name:
        real_display_name = str(given_name).strip()
    elif given_name and family_name:
        real_display_name = f"{given_name} {family_name}".strip()
    elif given_name:
        real_display_name = given_name
    elif family_name:
        real_display_name = family_name
    else:
        real_display_name = (
            claims.get("name")
            or claims.get("displayName")
            or real_email.split("@")[0]           # last-resort: use local part of email
        )

    if doc is None:
        # User not found. Auto-create/provision the tenant & user.
        role_str = claims.get("extension_Role") or "student"

        # Ensure tenant exists
        from app.models.tenant import Tenant, TenantType
        from uuid import uuid4

        tenants_col = get_collection("platform", "tenants")
        tenant_doc = await tenants_col.find_one({"_id": tenant_id})
        if tenant_doc is None:
            tenant = Tenant(
                **{"_id": tenant_id},
                name=f"{real_display_name}'s Family/School",
                type=TenantType.family,
                admin_email=real_email,
            )
            await tenants_col.insert_one(tenant.model_dump(by_alias=True))
            logger.info(f"Auto-created tenant: {tenant_id}")

        user_id = f"usr_{uuid4().hex}"
        try:
            role = UserRole(role_str)
        except ValueError:
            role = UserRole.student

        user = User(
            **{"_id": user_id},
            tenant_id=tenant_id,
            email=real_email,
            display_name=real_display_name,
            b2c_object_id=b2c_object_id,
            role=role,
        )
        await collection.insert_one(user.model_dump(by_alias=True))
        logger.info(f"Auto-created user: {user_id} for b2c_object_id: {b2c_object_id}")
        doc = await collection.find_one({"_id": user_id})

    user = User.model_validate(doc)

    # --- Self-heal: patch placeholder email/name from live token claims ------
    # If this user was previously created before we had the correct claim
    # extraction, update their profile with the real values now.
    patch: dict[str, Any] = {}
    if user.email == _PLACEHOLDER_EMAIL and real_email != _PLACEHOLDER_EMAIL:
        patch["email"] = real_email
        logger.info(
            "Patching placeholder email for user=%s → %s", user.id, real_email
        )
    if user.display_name != real_display_name and real_display_name:
        patch["display_name"] = real_display_name

    if patch:
        await collection.update_one({"_id": user.id}, {"$set": patch})
        # Re-fetch so the returned object is consistent with what's in the DB.
        doc = await collection.find_one({"_id": user.id})
        user = User.model_validate(doc)
        # Bust the Redis cache so the next request gets the fresh record.
        await redis.delete(cache_key)

    await redis.setex(cache_key, _USER_TTL_SECONDS, user.model_dump_json())
    return user



async def _ensure_self_learning_workspace(user: User) -> User:
    """Ensure the user has a self-learning workspace.

    Self-learning is a student-only product surface. Admin accounts manage
    shared classroom/family workspaces and must never receive a personal
    workspace in the admin app.

    Creates ``wsp_self_{user_id}`` for students when missing and appends the
    membership. Existing admin self-workspaces are left untouched in storage;
    the workspace and profile APIs filter them from admin responses.
    """
    if user.role != UserRole.student:
        return user

    self_ws_id = f"wsp_self_{user.id}"
    has_self = any(m.workspace_id == self_ws_id for m in user.workspace_memberships)
    if not has_self:
        col = get_collection(user.tenant_id, WORKSPACES)
        ws = await col.find_one({"_id": self_ws_id})
        if not ws:
            workspace = Workspace(
                **{"_id": self_ws_id},
                tenant_id=user.tenant_id,
                name="Self Learning Workspace",
                description="Your personal self-learning workspace",
                admin_ids=[user.id],
            )
            await col.insert_one(workspace.model_dump(by_alias=True))
            logger.info("Auto-created self-learning workspace %s for user %s", self_ws_id, user.id)

        user.workspace_memberships.append(
            WorkspaceMembership(
                workspace_id=self_ws_id,
                role=UserRole.workspace_admin,
                joined_at=utc_now(),
            )
        )
        user.touch()
        user_col = get_collection(user.tenant_id, USERS)
        await user_col.replace_one({"_id": user.id}, user.model_dump(by_alias=True))

        # Bust the Redis cache so updates propagate
        if user.b2c_object_id:
            try:
                redis = await get_redis()
                cache_key = f"user:{user.tenant_id}:{user.b2c_object_id}"
                await redis.delete(cache_key)
            except Exception as e:
                logger.warning("Failed to invalidate cache after adding self workspace: %s", e)
    return user


async def get_current_user(
    request: Request,
    credentials: HTTPAuthorizationCredentials | None = Depends(_bearer),
) -> User:
    """FastAPI dependency — extracts and validates the calling user.

    Raises UnauthorizedError when no valid token is present.
    The tenant_id claim embedded in the token identifies which Cosmos database to query.
    """
    if credentials is None:
        raise UnauthorizedError()

    # Dev-auth bypass check
    if (
        settings.environment != "production"
        and settings.dev_auth_token
        and credentials.credentials == settings.dev_auth_token
    ):
        tenant_id = settings.dev_auth_tenant_id
        user_id = settings.dev_auth_user_id
        col = get_collection(tenant_id, USERS)
        doc = await col.find_one({"_id": user_id, "deleted_at": None})
        if doc is None:
            raise UnauthorizedError(
                f"Dev auth user {user_id} not found in database for tenant {tenant_id}."
            )
        user = User.model_validate(doc)
        user = await _ensure_self_learning_workspace(user)
        request.state.user = user
        return user

    claims = await _validate_token(credentials.credentials)
    b2c_object_id: str = claims.get("sub", "")
    # Default to the app's B2C Client ID if the user didn't provide a tenant ID during sign up
    tenant_id: str = claims.get("extension_TenantId") or settings.b2c_client_id or "ten_demo_001"

    if not b2c_object_id:
        raise UnauthorizedError("Token missing required sub claim")

    user = await _lookup_or_create_user(b2c_object_id, tenant_id, claims)
    if not user.is_active:
        raise UnauthorizedError("Account is disabled")

    user = await _ensure_self_learning_workspace(user)
    request.state.user = user
    return user


def require_role(*roles: UserRole):
    """Dependency factory — restrict an endpoint to specific roles.

    Usage::
        @router.post("/", dependencies=[Depends(require_role(UserRole.tenant_admin))])
    """

    async def _check(user: User = Depends(get_current_user)) -> User:
        if user.role not in roles:
            raise ForbiddenError(
                f"This action requires one of: {', '.join(r.value for r in roles)}"
            )
        return user

    return _check


async def invalidate_user_cache(user: User) -> None:
    """Invalidate the cached User document in Redis."""
    if not user.b2c_object_id:
        return
    try:
        redis = await get_redis()
        cache_key = f"user:{user.tenant_id}:{user.b2c_object_id}"
        await redis.delete(cache_key)
        logger.info(f"Invalidated Redis cache for user {user.id}")
    except Exception as e:
        logger.error(f"Failed to invalidate user cache for user {user.id}: {e}")

