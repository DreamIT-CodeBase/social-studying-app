"""Unit test fixtures — all external dependencies are mocked."""

from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.models.user import User, UserRole, WorkspaceMembership
from app.models.workspace import Workspace

# ── Fake data factories ───────────────────────────────────────────────────────


def make_user(
    user_id: str = "usr_test001",
    tenant_id: str = "ten_test001",
    role: UserRole = UserRole.tenant_admin,
    workspace_ids: list[str] | None = None,
) -> User:
    memberships = [
        WorkspaceMembership(workspace_id=wid, role=role, joined_at="2026-01-01T00:00:00+00:00")
        for wid in (workspace_ids or [])
    ]
    return User(
        **{"_id": user_id},
        tenant_id=tenant_id,
        email="test@example.com",
        display_name="Test User",
        role=role,
        workspace_memberships=memberships,
    )


def make_workspace(
    workspace_id: str = "wsp_test001",
    tenant_id: str = "ten_test001",
    admin_ids: list[str] | None = None,
) -> Workspace:
    return Workspace(
        **{"_id": workspace_id},
        tenant_id=tenant_id,
        name="Test Workspace",
        admin_ids=admin_ids or ["usr_test001"],
    )


# ── Auth bypass fixture ───────────────────────────────────────────────────────


@pytest.fixture
def auth_as_admin():
    """Override get_current_user to return a tenant admin without hitting B2C."""
    user = make_user(role=UserRole.tenant_admin)
    with patch("app.core.auth.get_current_user", return_value=user):
        yield user


@pytest.fixture
def auth_as_workspace_admin():
    user = make_user(
        role=UserRole.workspace_admin,
        workspace_ids=["wsp_test001"],
    )
    with patch("app.core.auth.get_current_user", return_value=user):
        yield user


@pytest.fixture
def auth_as_student():
    user = make_user(
        user_id="usr_student01",
        role=UserRole.student,
        workspace_ids=["wsp_test001"],
    )
    with patch("app.core.auth.get_current_user", return_value=user):
        yield user


# ── Database mock fixture ─────────────────────────────────────────────────────


@pytest.fixture
def mock_collection():
    """Return a MagicMock that behaves like an AsyncIOMotorCollection."""

    class _AsyncCursor:
        def __init__(self, docs: list[dict]) -> None:
            self._docs = docs
            self._idx = 0

        def __aiter__(self):
            return self

        async def __anext__(self) -> dict:
            if self._idx >= len(self._docs):
                raise StopAsyncIteration
            doc = self._docs[self._idx]
            self._idx += 1
            return doc

    col = MagicMock()
    col.find_one = AsyncMock(return_value=None)
    col.insert_one = AsyncMock(return_value=MagicMock(inserted_id="test_id"))
    col.replace_one = AsyncMock(return_value=MagicMock(matched_count=1))
    col.update_one = AsyncMock(return_value=MagicMock(matched_count=1))
    col.find = MagicMock(return_value=_AsyncCursor([]))

    return col


@pytest.fixture
def mock_db(mock_collection):
    """Patch get_collection to return mock_collection for every call."""
    with patch("app.core.database.get_collection", return_value=mock_collection) as patched:
        yield patched, mock_collection
