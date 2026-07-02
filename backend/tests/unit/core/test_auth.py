"""Unit tests for auth middleware — JWT validation, user lookup, role guard."""

from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from fastapi import Request
from fastapi.security import HTTPAuthorizationCredentials

from app.core.auth import (
    _validate_token,
    get_current_user,
    require_role,
    _lookup_or_create_user,
)
from app.core.config import settings
from app.core.exceptions import ForbiddenError, UnauthorizedError
from app.models.user import UserRole
from tests.unit.conftest import make_user

# ── _validate_token ───────────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_validate_token_invalid_raises_unauthorized():
    with (
        patch("app.core.auth._get_jwks", AsyncMock(return_value={"keys": []})),
        pytest.raises(UnauthorizedError),
    ):
        await _validate_token("not.a.real.token")


@pytest.mark.asyncio
async def test_validate_token_valid_returns_claims():
    fake_claims = {"sub": "obj_123", "extension_TenantId": "ten_001", "aud": "client_id"}
    with (
        patch("app.core.auth._get_jwks", AsyncMock(return_value={"keys": []})),
        patch("app.core.auth.jwt.decode", return_value=fake_claims),
    ):
        claims = await _validate_token("valid.token.here")
    assert claims["sub"] == "obj_123"
    assert claims["extension_TenantId"] == "ten_001"


@pytest.mark.asyncio
async def test_validate_token_google_returns_claims():
    google_claims = {
        "sub": "google_123",
        "iss": "https://accounts.google.com",
        "email": "google@example.com",
        "name": "Google User",
    }
    with (
        patch("app.core.auth._get_google_jwks", AsyncMock(return_value={"keys": []})),
        patch("app.core.auth.jwt.get_unverified_claims", return_value={"iss": "https://accounts.google.com"}),
        patch("app.core.auth.jwt.decode", return_value=google_claims),
    ):
        claims = await _validate_token("google.token.here")
    assert claims["sub"] == "google_123"
    assert claims["iss"] == "https://accounts.google.com"


# ── get_current_user ──────────────────────────────────────────────────────────


def _make_request() -> Request:
    scope = {"type": "http", "method": "GET", "path": "/", "headers": []}
    return Request(scope)


@pytest.mark.asyncio
async def test_get_current_user_no_credentials_raises_unauthorized():
    request = _make_request()
    with pytest.raises(UnauthorizedError):
        await get_current_user(request, credentials=None)


@pytest.mark.asyncio
async def test_get_current_user_missing_sub_raises_unauthorized():
    request = _make_request()
    creds = HTTPAuthorizationCredentials(scheme="Bearer", credentials="tok")
    with (
        patch(
            "app.core.auth._validate_token",
            AsyncMock(return_value={"sub": "", "extension_TenantId": "ten_001"}),
        ),
        pytest.raises(UnauthorizedError, match="Token missing required sub claim"),
    ):
        await get_current_user(request, credentials=creds)


@pytest.mark.asyncio
async def test_get_current_user_inactive_account_raises_unauthorized():
    request = _make_request()
    creds = HTTPAuthorizationCredentials(scheme="Bearer", credentials="tok")
    inactive_user = make_user(role=UserRole.student)
    inactive_user.is_active = False

    with (
        patch(
            "app.core.auth._validate_token",
            AsyncMock(return_value={"sub": "obj_123", "extension_TenantId": "ten_001"}),
        ),
        patch("app.core.auth._lookup_or_create_user", AsyncMock(return_value=inactive_user)),
        pytest.raises(UnauthorizedError, match="Account is disabled"),
    ):
        await get_current_user(request, credentials=creds)


@pytest.mark.asyncio
async def test_get_current_user_happy_path_returns_user_and_sets_state():
    request = _make_request()
    request._state = MagicMock()
    creds = HTTPAuthorizationCredentials(scheme="Bearer", credentials="tok")
    expected_user = make_user(role=UserRole.tenant_admin)

    with (
        patch(
            "app.core.auth._validate_token",
            AsyncMock(return_value={"sub": "obj_123", "extension_TenantId": "ten_test001"}),
        ),
        patch("app.core.auth._lookup_or_create_user", AsyncMock(return_value=expected_user)),
        patch("app.core.auth._ensure_self_learning_workspace", AsyncMock(side_effect=lambda u: u)),
    ):
        user = await get_current_user(request, credentials=creds)

    assert user.id == expected_user.id
    assert request.state.user == expected_user


# ── require_role ──────────────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_require_role_allowed_passes():
    admin = make_user(role=UserRole.tenant_admin)
    with patch("app.core.auth.get_current_user", AsyncMock(return_value=admin)):
        guard = require_role(UserRole.tenant_admin)
        result = await guard(admin)
    assert result == admin


@pytest.mark.asyncio
async def test_require_role_wrong_role_raises_forbidden():
    student = make_user(role=UserRole.student)
    with patch("app.core.auth.get_current_user", AsyncMock(return_value=student)):
        guard = require_role(UserRole.tenant_admin, UserRole.workspace_admin)
        with pytest.raises(ForbiddenError):
            await guard(student)


@pytest.mark.asyncio
async def test_require_role_multiple_allowed_roles():
    ws_admin = make_user(role=UserRole.workspace_admin)
    guard = require_role(UserRole.tenant_admin, UserRole.workspace_admin)
    result = await guard(ws_admin)
    assert result.role == UserRole.workspace_admin


# ── _lookup_or_create_user (cache miss + hit + auto creation) ──────────────────


@pytest.mark.asyncio
async def test_lookup_or_create_user_cache_miss_hits_db():
    user = make_user()

    fake_redis = AsyncMock()
    fake_redis.get = AsyncMock(return_value=None)
    fake_redis.setex = AsyncMock()

    fake_col = MagicMock()
    fake_col.find_one = AsyncMock(return_value=user.model_dump(by_alias=True))
    fake_col.update_one = AsyncMock()

    with (
        patch("app.core.auth.get_redis", AsyncMock(return_value=fake_redis)),
        patch("app.core.auth.get_collection", return_value=fake_col),
    ):
        claims = {"email": "test@example.com", "name": "Test User"}
        result = await _lookup_or_create_user("obj_123", "ten_test001", claims)

    assert result.id == user.id
    fake_redis.setex.assert_called_once()


@pytest.mark.asyncio
async def test_lookup_or_create_user_cache_hit_skips_db():
    user = make_user()
    user_json = user.model_dump_json()

    fake_redis = AsyncMock()
    fake_redis.get = AsyncMock(return_value=user_json)

    with (
        patch("app.core.auth.get_redis", AsyncMock(return_value=fake_redis)),
        patch("app.core.auth.get_collection") as mock_get_col,
    ):
        result = await _lookup_or_create_user("obj_123", "ten_test001", {})

    mock_get_col.assert_not_called()
    assert result.id == user.id


@pytest.mark.asyncio
async def test_lookup_or_create_user_not_found_creates_user():
    fake_redis = AsyncMock()
    fake_redis.get = AsyncMock(return_value=None)
    fake_redis.setex = AsyncMock()

    # DB collection simulation: return None (user not found), then simulate insert and subsequent find returning the user doc
    fake_users_col = MagicMock()
    fake_users_col.find_one = AsyncMock(side_effect=[None, None, {
        "_id": "usr_created_123",
        "tenant_id": "ten_test001",
        "email": "test@example.com",
        "display_name": "Test User",
        "b2c_object_id": "unknown",
        "role": "student",
        "is_active": True,
        "created_at": "2026-06-08T00:00:00",
    }])
    fake_users_col.insert_one = AsyncMock()

    fake_tenants_col = MagicMock()
    fake_tenants_col.find_one = AsyncMock(return_value={"_id": "ten_test001", "name": "Test Tenant"})

    def get_collection_mock(db_name, col_name):
        if db_name == "platform" and col_name == "tenants":
            return fake_tenants_col
        return fake_users_col

    with (
        patch("app.core.auth.get_redis", AsyncMock(return_value=fake_redis)),
        patch("app.core.auth.get_collection", side_effect=get_collection_mock),
    ):
        claims = {"email": "test@example.com", "name": "Test User", "extension_Role": "student"}
        result = await _lookup_or_create_user("unknown", "ten_test001", claims)

    assert result.email == "test@example.com"
    assert result.display_name == "Test User"
    assert result.role == UserRole.student
    fake_users_col.insert_one.assert_called_once()
