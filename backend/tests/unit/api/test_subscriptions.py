"""Unit tests for Subscription and Stripe Checkout API endpoints."""

from __future__ import annotations

from datetime import UTC
from unittest.mock import AsyncMock, patch

import pytest
from fastapi.testclient import TestClient

from app.core.auth import get_current_user
from app.main import app
from app.models.subscription import SubscriptionStatus
from app.models.user import UserRole
from tests.unit.conftest import make_user


@pytest.fixture
def client() -> TestClient:
    yield TestClient(app, raise_server_exceptions=True)
    app.dependency_overrides.clear()


@pytest.fixture
def student():
    user = make_user(
        user_id="usr_stu_001",
        role=UserRole.student,
    )
    app.dependency_overrides[get_current_user] = lambda: user
    return user


@pytest.fixture
def workspace_admin():
    user = make_user(
        user_id="usr_adm_001",
        role=UserRole.workspace_admin,
    )
    app.dependency_overrides[get_current_user] = lambda: user
    return user


def test_get_plans(client):
    response = client.get("/api/v1/subscriptions/plans")
    assert response.status_code == 200
    plans = response.json()
    assert len(plans) >= 2
    plan_ids = [p["plan_id"] for p in plans]
    assert "monthly" in plan_ids
    assert "annual" in plan_ids


def test_get_subscription_me_no_subscription(client, student):
    mock_collection = AsyncMock()
    mock_collection.find_one = AsyncMock(return_value=None)

    with patch("app.services.stripe_service.get_collection", return_value=mock_collection):
        response = client.get("/api/v1/subscriptions/me")
        assert response.status_code == 200
        data = response.json()
        assert data["has_active_subscription"] is False
        assert data["role"] == "student"
        assert data["subscription"] is None
        assert len(data["available_plans"]) >= 2


def test_get_subscription_me_admin_fallback(client, workspace_admin):
    mock_collection = AsyncMock()
    mock_collection.find_one = AsyncMock(return_value=None)

    with patch("app.services.stripe_service.get_collection", return_value=mock_collection):
        response = client.get("/api/v1/subscriptions/me")
        assert response.status_code == 200
        data = response.json()
        # Pre-existing workspace admins are considered active
        assert data["has_active_subscription"] is True
        assert data["role"] == "workspace_admin"


def test_create_checkout_session_mock_mode(client, student):
    mock_sub_col = AsyncMock()
    mock_sub_col.insert_one = AsyncMock(return_value=None)

    with patch("app.services.stripe_service.is_stripe_configured", return_value=False), \
         patch("app.services.stripe_service.get_collection", return_value=mock_sub_col):
        response = client.post(
            "/api/v1/subscriptions/checkout-session",
            json={"plan_id": "monthly"},
        )
        assert response.status_code == 201
        data = response.json()
        assert "session_id" in data
        assert "checkout_url" in data
        assert data["session_id"].startswith("cs_test_")
        assert "payment-success" in data["checkout_url"]


def test_verify_session_promotes_student_to_admin(client, student):
    mock_sub_col = AsyncMock()
    mock_sub_col.find_one = AsyncMock(return_value=None)
    mock_sub_col.insert_one = AsyncMock(return_value=None)

    mock_user_col = AsyncMock()
    mock_user_col.update_one = AsyncMock(return_value=None)

    mock_tenant_col = AsyncMock()
    mock_tenant_col.update_one = AsyncMock(return_value=None)

    def fake_get_collection(tenant_or_db, name):
        if name == "subscriptions":
            return mock_sub_col
        if name == "users":
            return mock_user_col
        if name == "tenants":
            return mock_tenant_col
        return AsyncMock()

    with patch("app.services.stripe_service.get_collection", side_effect=fake_get_collection), \
         patch("app.services.stripe_service.invalidate_user_cache", new_callable=AsyncMock):
        response = client.post(
            "/api/v1/subscriptions/verify-session",
            json={"session_id": "cs_test_12345"},
        )
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == SubscriptionStatus.active.value
        assert data["user_id"] == student.id
        assert student.role == UserRole.workspace_admin
        assert mock_user_col.update_one.called
        assert mock_tenant_col.update_one.called


def test_stripe_webhook_completed(client):
    webhook_payload = {
        "type": "checkout.session.completed",
        "data": {
            "object": {
                "id": "cs_test_hook",
                "client_reference_id": "usr_stu_001",
                "metadata": {"user_id": "usr_stu_001", "tenant_id": "ten_test001", "plan_id": "monthly"},
            }
        },
    }

    mock_user_doc = {
        "_id": "usr_stu_001",
        "tenant_id": "ten_test001",
        "email": "test@example.com",
        "display_name": "Test User",
        "role": "student",
        "workspace_memberships": [],
        "created_at": "2026-01-01T00:00:00Z",
        "updated_at": "2026-01-01T00:00:00Z",
    }

    mock_user_col = AsyncMock()
    mock_user_col.find_one = AsyncMock(return_value=mock_user_doc)
    mock_user_col.update_one = AsyncMock(return_value=None)

    mock_sub_col = AsyncMock()
    mock_sub_col.find_one = AsyncMock(return_value=None)
    mock_sub_col.insert_one = AsyncMock(return_value=None)

    mock_tenant_col = AsyncMock()
    mock_tenant_col.update_one = AsyncMock(return_value=None)

    def fake_get_collection(tenant_or_db, name):
        if name == "subscriptions":
            return mock_sub_col
        if name == "users":
            return mock_user_col
        if name == "tenants":
            return mock_tenant_col
        return AsyncMock()

    with patch("app.services.stripe_service.get_collection", side_effect=fake_get_collection), \
         patch("app.services.stripe_service.invalidate_user_cache", new_callable=AsyncMock):
        response = client.post(
            "/api/v1/subscriptions/webhook",
            json=webhook_payload,
        )
        assert response.status_code == 200
        assert response.json() == {"received": True, "event": "checkout.session.completed"}


def test_direct_stripe_webhook_endpoint(client):
    webhook_payload = {
        "type": "checkout.session.completed",
        "data": {
            "object": {
                "id": "cs_test_hook_direct",
                "client_reference_id": "usr_stu_001",
                "metadata": {"user_id": "usr_stu_001", "tenant_id": "ten_test001", "plan_id": "monthly"},
            }
        },
    }

    mock_user_doc = {
        "_id": "usr_stu_001",
        "tenant_id": "ten_test001",
        "email": "test@example.com",
        "display_name": "Test User",
        "role": "student",
        "workspace_memberships": [],
        "created_at": "2026-01-01T00:00:00Z",
        "updated_at": "2026-01-01T00:00:00Z",
    }

    mock_user_col = AsyncMock()
    mock_user_col.find_one = AsyncMock(return_value=mock_user_doc)
    mock_user_col.update_one = AsyncMock(return_value=None)

    mock_sub_col = AsyncMock()
    mock_sub_col.find_one = AsyncMock(return_value=None)
    mock_sub_col.insert_one = AsyncMock(return_value=None)

    mock_tenant_col = AsyncMock()
    mock_tenant_col.update_one = AsyncMock(return_value=None)

    def fake_get_collection(tenant_or_db, name):
        if name == "subscriptions":
            return mock_sub_col
        if name == "users":
            return mock_user_col
        if name == "tenants":
            return mock_tenant_col
        return AsyncMock()

    with patch("app.services.stripe_service.get_collection", side_effect=fake_get_collection), \
         patch("app.services.stripe_service.invalidate_user_cache", new_callable=AsyncMock):
        response = client.post(
            "/api/stripe/webhook",
            json=webhook_payload,
        )
        assert response.status_code == 200
        assert response.json() == {"received": True, "event": "checkout.session.completed"}


def test_send_and_verify_email_otp(client):
    from datetime import datetime, timedelta

    from app.services.otp_service import _hash_code

    mock_otp_col = AsyncMock()
    mock_otp_col.count_documents = AsyncMock(return_value=0)
    mock_otp_col.insert_one = AsyncMock(return_value=None)
    mock_otp_col.update_one = AsyncMock(return_value=None)
    mock_otp_col.update_many = AsyncMock(return_value=None)

    mock_sender = AsyncMock()
    mock_sender.send = AsyncMock(return_value=None)

    with patch("app.services.otp_service.get_collection", return_value=mock_otp_col), \
         patch("app.services.otp_service.get_email_sender", return_value=mock_sender):
        # 1. Send OTP
        resp = client.post("/api/v1/subscriptions/send-email-otp", json={"email": "Admin@Test.com"})
        assert resp.status_code == 200
        data = resp.json()
        assert "message" in data
        assert data["expires_in_seconds"] == 600
        assert mock_sender.send.called

        # 2. Verify wrong OTP
        mock_doc = {
            "_id": "otp_test123",
            "email": "admin@test.com",
            "code_hash": _hash_code("123456", "salt123"),
            "salt": "salt123",
            "expires_at": (datetime.now(UTC) + timedelta(minutes=10)).isoformat(),
            "attempts": 0,
            "verified": False,
            "invalidated": False,
        }
        mock_otp_col.find_one = AsyncMock(return_value=mock_doc)

        wrong_resp = client.post(
            "/api/v1/subscriptions/verify-email-otp",
            json={"email": "admin@test.com", "otp": "000000"},
        )
        assert wrong_resp.status_code == 400

        # 3. Verify correct OTP
        valid_resp = client.post(
            "/api/v1/subscriptions/verify-email-otp",
            json={"email": "admin@test.com", "otp": "123456"},
        )
        assert valid_resp.status_code == 200
        valid_data = valid_resp.json()
        assert valid_data["verified"] is True
        assert "verification_token" in valid_data


def test_student_trial_status(client, student):
    mock_sub_col = AsyncMock()
    mock_sub_col.find_one = AsyncMock(return_value=None)

    with patch("app.services.stripe_service.get_collection", return_value=mock_sub_col):
        resp = client.get("/api/v1/subscriptions/student/status")
        assert resp.status_code == 200
        data = resp.json()
        assert data["is_trial"] is True
        assert data["is_trial_expired"] is False
        assert data["can_access_study"] is True


def test_handoff_token(client, student):
    resp = client.post("/api/v1/subscriptions/handoff-token")
    assert resp.status_code == 200
    data = resp.json()
    assert "handoff_token" in data
    assert "redirect_url" in data
    assert "token=" in data["redirect_url"]

