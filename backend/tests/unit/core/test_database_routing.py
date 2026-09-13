"""Regression tests for cost-safe, tenant-isolated Cosmos routing."""

from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.core.database import TenantScopedCollection, TenantScopeViolation, get_collection


def test_dynamic_tenants_use_fixed_collections_in_shared_database():
    client = MagicMock()

    with patch("app.core.database._get_client", return_value=client):
        result = get_collection("ten_abc123", "users")

    client.__getitem__.assert_called_once_with("tenant_data_shared")
    client.__getitem__.return_value.__getitem__.assert_called_once_with("users")
    assert isinstance(result, TenantScopedCollection)


@pytest.mark.asyncio
async def test_reads_always_include_tenant_scope():
    physical = MagicMock()
    physical.find_one = AsyncMock(return_value=None)
    collection = TenantScopedCollection(physical, "ten_alpha")

    await collection.find_one({"_id": "usr_1"})

    physical.find_one.assert_awaited_once_with({"_id": "usr_1", "tenant_id": "ten_alpha"})


@pytest.mark.asyncio
async def test_inserts_are_stamped_with_tenant_scope():
    physical = MagicMock()
    physical.insert_one = AsyncMock()
    collection = TenantScopedCollection(physical, "ten_alpha")

    await collection.insert_one({"_id": "usr_1", "email": "a@example.com"})

    physical.insert_one.assert_awaited_once_with(
        {"_id": "usr_1", "email": "a@example.com", "tenant_id": "ten_alpha"}
    )


@pytest.mark.asyncio
async def test_cross_tenant_reads_are_rejected():
    collection = TenantScopedCollection(MagicMock(), "ten_alpha")

    with pytest.raises(TenantScopeViolation):
        await collection.find_one({"tenant_id": "ten_beta"})


@pytest.mark.asyncio
async def test_cross_tenant_writes_are_rejected():
    collection = TenantScopedCollection(MagicMock(), "ten_alpha")

    with pytest.raises(TenantScopeViolation):
        await collection.insert_one({"_id": "usr_1", "tenant_id": "ten_beta"})


def test_platform_database_is_not_wrapped():
    client = MagicMock()

    with patch("app.core.database._get_client", return_value=client):
        result = get_collection("platform", "tenants")

    assert result is client.__getitem__.return_value.__getitem__.return_value


def test_configured_demo_database_is_not_wrapped():
    client = MagicMock()

    with patch("app.core.database._get_client", return_value=client):
        result = get_collection("ten_demo_001", "users")

    assert result is client.__getitem__.return_value.__getitem__.return_value
