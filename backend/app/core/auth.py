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

from app.core.config import settings
from app.core.database import USERS, get_collection
from app.core.exceptions import ForbiddenError, UnauthorizedError
from app.core.redis_client import get_redis
from app.models.user import User, UserRole

logger = logging.getLogger(__name__)

_bearer = HTTPBearer(auto_error=False)

# Redis TTLs
_JWKS_TTL_SECONDS = 86_400   # 24 h — JWKS rotates infrequently
_USER_TTL_SECONDS = 300       # 5 min — role/membership changes should propagate quickly


def _jwks_url() -> str:
    """Return the JWKS endpoint for our Entra External ID (CIAM) tenant.

    Project is on Entra External ID, not classic B2C — the URL form is
    ``{tenant_id}.ciamlogin.com/{tenant_id}/discovery/v2.0/keys`` with no
    .onmicrosoft.com domain and no policy segment. (Classic B2C used
    ``b2clogin.com`` and a policy-scoped path; that form returns DNS
    failures against our tenant. See memory/auth_provider_decision.md.)
    """
    return (
        f"https://{settings.b2c_tenant_id}.ciamlogin.com/"
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


async def _validate_token(token: str) -> dict[str, Any]:
    """Validate a B2C JWT and return its claims."""
    try:
        jwks = await _get_jwks()
        claims: dict[str, Any] = jwt.decode(
            token,
            jwks,
            algorithms=["RS256"],
            audience=settings.b2c_client_id,
            options={"verify_at_hash": False},
        )
        return claims
    except JWTError as exc:
        raise UnauthorizedError(f"Invalid token: {exc}") from exc


async def _lookup_user(b2c_object_id: str, tenant_id: str) -> User:
    """Look up the User document, cached in Redis for 5 minutes."""
    redis = await get_redis()
    cache_key = f"user:{tenant_id}:{b2c_object_id}"
    cached = await redis.get(cache_key)
    if cached:
        return User.model_validate_json(cached)

    collection = get_collection(tenant_id, USERS)
    doc = await collection.find_one({"b2c_object_id": b2c_object_id, "deleted_at": None})
    if doc is None:
        raise UnauthorizedError("User account not found")

    user = User.model_validate(doc)
    await redis.setex(cache_key, _USER_TTL_SECONDS, user.model_dump_json())
    return user


def _dev_auth_active() -> bool:
    """Whether the dev-auth bypass may run for this process.

    Double-gated: never in production, and only when an operator has set a
    non-empty ``dev_auth_token``. Both conditions must hold, so a prod
    deploy (which leaves the token empty) can never accept the bypass even
    if ``environment`` were ever misconfigured.
    """
    return settings.environment != "production" and bool(settings.dev_auth_token)


async def _resolve_dev_user(token: str) -> User | None:
    """Resolve the sentinel dev-auth token to the seeded demo user.

    Returns None when the token doesn't match (so the caller falls through
    to normal JWT validation). Raises UnauthorizedError when the token
    matches but the demo identity hasn't been seeded — that's an operator
    error (run scripts/seed_demo_tenant.py), surfaced loudly rather than
    silently degrading to a 401 that looks like a bad token.
    """
    if token != settings.dev_auth_token:
        return None

    collection = get_collection(settings.dev_auth_tenant_id, USERS)
    doc = await collection.find_one(
        {"_id": settings.dev_auth_user_id, "deleted_at": None}
    )
    if doc is None:
        raise UnauthorizedError(
            "Dev-auth token accepted but demo user is not seeded. "
            "Run backend/scripts/seed_demo_tenant.py against this environment."
        )
    return User.model_validate(doc)


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

    # Dev-auth bypass (non-prod only) — short-circuits JWT validation for
    # the seeded demo identity so the still-mocked Flutter login can drive
    # the real backend. See settings.dev_auth_token.
    if _dev_auth_active():
        dev_user = await _resolve_dev_user(credentials.credentials)
        if dev_user is not None:
            if not dev_user.is_active:
                raise UnauthorizedError("Account is disabled")
            request.state.user = dev_user
            return dev_user

    claims = await _validate_token(credentials.credentials)
    b2c_object_id: str = claims.get("sub", "")
    tenant_id: str = claims.get("extension_TenantId", "")

    if not b2c_object_id or not tenant_id:
        raise UnauthorizedError("Token missing required claims")

    user = await _lookup_user(b2c_object_id, tenant_id)
    if not user.is_active:
        raise UnauthorizedError("Account is disabled")

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
