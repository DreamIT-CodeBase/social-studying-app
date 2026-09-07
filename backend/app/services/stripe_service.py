"""Stripe payment gateway & subscription service.

Handles:
1. Customer creation & hosted Stripe Checkout session generation.
2. Immediate session verification & user promotion to workspace_admin on app redirect.
3. Webhook handling for background events (renewal, cancellation, failures).
4. Graceful mock mode when Stripe API keys are not configured (local dev & CI).
"""

import json
import logging
from datetime import UTC, datetime, timedelta
from typing import Any
from uuid import uuid4

import stripe

from app.core.auth import invalidate_user_cache
from app.core.config import settings
from app.core.database import SUBSCRIPTIONS, USERS, get_collection
from app.core.exceptions import BadRequestError
from app.models.base import utc_now
from app.models.subscription import (
    CheckoutSessionResponse,
    PlanOption,
    Subscription,
    SubscriptionPlan,
    SubscriptionStatus,
)
from app.models.tenant import TenantStatus
from app.models.user import User, UserRole

logger = logging.getLogger(__name__)

# Configure Stripe SDK
if settings.stripe_secret_key:
    stripe.api_key = settings.stripe_secret_key

# Standard plan definitions
PLAN_DETAILS: dict[SubscriptionPlan, dict[str, Any]] = {
    SubscriptionPlan.monthly: {
        "name": "Social Studying Admin (Monthly)",
        "description": "Full access to create & manage classrooms, AI question sets, and screen time rules.",
        "amount": 1900,  # $19.00
        "currency": "usd",
        "interval": "month",
        "duration_days": 30,
    },
    SubscriptionPlan.annual: {
        "name": "Social Studying Admin (Annual)",
        "description": "Full access for 1 full year with 2 months free.",
        "amount": 19000,  # $190.00
        "currency": "usd",
        "interval": "year",
        "duration_days": 365,
    },
    SubscriptionPlan.pro_admin: {
        "name": "Social Studying Pro Admin",
        "description": "Unlimited workspaces, multi-teacher roster management, and advanced analytics.",
        "amount": 2900,  # $29.00
        "currency": "usd",
        "interval": "month",
        "duration_days": 30,
    },
}


def is_stripe_configured() -> bool:
    """Return True if a live or test Stripe API key is set."""
    return bool(settings.stripe_secret_key and settings.stripe_secret_key.strip())


def get_available_plans() -> list[PlanOption]:
    """Return all selectable subscription plans."""
    plans = []
    for plan_id, details in PLAN_DETAILS.items():
        plans.append(
            PlanOption(
                plan_id=plan_id,
                name=details["name"],
                description=details["description"],
                amount=details["amount"],
                currency=details["currency"],
                interval=details["interval"],
            )
        )
    return plans


async def create_checkout_session(
    user: User,
    plan_id: SubscriptionPlan = SubscriptionPlan.monthly,
    success_url: str | None = None,
    cancel_url: str | None = None,
) -> CheckoutSessionResponse:
    """Create a hosted Stripe Checkout Session for subscription purchase."""
    plan_info = PLAN_DETAILS.get(plan_id, PLAN_DETAILS[SubscriptionPlan.monthly])
    scheme = settings.stripe_app_redirect_scheme or "socialstudy"

    default_success_url = f"{scheme}://app/payment-success?session_id={{CHECKOUT_SESSION_ID}}"
    default_cancel_url = f"{scheme}://app/payment-cancelled"

    final_success_url = success_url or default_success_url
    final_cancel_url = cancel_url or default_cancel_url

    if is_stripe_configured():
        stripe.api_key = settings.stripe_secret_key

        # Resolve or create Stripe customer
        customer_id: str | None = None
        sub_col = get_collection(user.tenant_id, SUBSCRIPTIONS)
        existing_sub = await sub_col.find_one({"user_id": user.id, "deleted_at": None})

        if existing_sub and existing_sub.get("stripe_customer_id"):
            customer_id = existing_sub["stripe_customer_id"]
        else:
            customer = stripe.Customer.create(
                email=user.email,
                name=user.display_name,
                metadata={"user_id": user.id, "tenant_id": user.tenant_id},
            )
            customer_id = customer.id

        # Determine price or dynamic price_data
        price_id = (
            settings.stripe_price_id_monthly
            if plan_id == SubscriptionPlan.monthly
            else settings.stripe_price_id_annual
        )

        if price_id:
            line_items = [{"price": price_id, "quantity": 1}]
        else:
            line_items = [
                {
                    "price_data": {
                        "currency": plan_info["currency"],
                        "product_data": {
                            "name": plan_info["name"],
                            "description": plan_info["description"],
                        },
                        "unit_amount": plan_info["amount"],
                        "recurring": {"interval": plan_info["interval"]},
                    },
                    "quantity": 1,
                }
            ]

        session = stripe.checkout.Session.create(
            customer=customer_id,
            payment_method_types=["card"],
            line_items=line_items,
            mode="subscription",
            success_url=final_success_url,
            cancel_url=final_cancel_url,
            client_reference_id=user.id,
            metadata={
                "user_id": user.id,
                "tenant_id": user.tenant_id,
                "plan_id": plan_id.value,
            },
        )

        logger.info(
            "Created Stripe Checkout session %s for user %s (plan %s)",
            session.id,
            user.id,
            plan_id,
        )
        return CheckoutSessionResponse(checkout_url=session.url or "", session_id=session.id)

    # ── Fallback mock mode for local dev / CI tests without real Stripe keys ──
    mock_id = f"cs_test_{uuid4().hex}"
    # Form deep-link redirect directly so manual testing can complete immediately
    mock_checkout_url = f"{scheme}://app/payment-success?session_id={mock_id}"

    # Pre-record pending subscription so verify_checkout_session knows the plan
    sub_col = get_collection(user.tenant_id, SUBSCRIPTIONS)
    mock_sub = Subscription(
        **{"_id": f"sub_{uuid4().hex}"},
        user_id=user.id,
        tenant_id=user.tenant_id,
        stripe_customer_id=f"cus_test_{uuid4().hex[:12]}",
        stripe_checkout_session_id=mock_id,
        status=SubscriptionStatus.trialing,
        plan_id=plan_id,
        amount=plan_info["amount"],
        currency=plan_info["currency"],
    )
    await sub_col.insert_one(mock_sub.model_dump(by_alias=True))

    logger.info("Created mock Stripe checkout session %s for user %s", mock_id, user.id)
    return CheckoutSessionResponse(checkout_url=mock_checkout_url, session_id=mock_id)


async def verify_checkout_session(session_id: str, current_user: User) -> Subscription:
    """Verify a completed checkout session and promote user to workspace_admin."""
    plan_id = SubscriptionPlan.monthly
    stripe_customer_id = f"cus_{uuid4().hex[:12]}"
    stripe_subscription_id: str | None = None

    if is_stripe_configured() and not session_id.startswith("cs_test_"):
        stripe.api_key = settings.stripe_secret_key
        try:
            session = stripe.checkout.Session.retrieve(session_id)
        except Exception as exc:
            logger.error("Failed to retrieve Stripe session %s: %s", session_id, exc)
            raise BadRequestError(f"Invalid or expired checkout session: {exc}") from exc

        if session.payment_status not in ("paid", "no_payment_required") and session.status != "complete":
            raise BadRequestError(f"Checkout session is not completed (status: {session.status})")

        stripe_customer_id = str(session.customer) if session.customer else stripe_customer_id
        stripe_subscription_id = str(session.subscription) if session.subscription else None
        if session.metadata and session.metadata.get("plan_id"):
            try:
                plan_id = SubscriptionPlan(session.metadata["plan_id"])
            except ValueError:
                plan_id = SubscriptionPlan.monthly
    else:
        # Mock mode verification
        logger.info("Verifying mock Stripe session %s", session_id)

    plan_info = PLAN_DETAILS.get(plan_id, PLAN_DETAILS[SubscriptionPlan.monthly])
    duration_days = plan_info["duration_days"]

    now = datetime.now(UTC)
    period_end = (now + timedelta(days=duration_days)).isoformat()
    period_start = now.isoformat()

    sub_col = get_collection(current_user.tenant_id, SUBSCRIPTIONS)
    existing = await sub_col.find_one({"user_id": current_user.id, "deleted_at": None})

    if existing:
        sub_id = existing["_id"]
        update_data = {
            "status": SubscriptionStatus.active.value,
            "plan_id": plan_id.value,
            "stripe_customer_id": stripe_customer_id,
            "stripe_subscription_id": stripe_subscription_id,
            "stripe_checkout_session_id": session_id,
            "amount": plan_info["amount"],
            "currency": plan_info["currency"],
            "current_period_start": period_start,
            "current_period_end": period_end,
            "updated_at": utc_now(),
        }
        await sub_col.update_one({"_id": sub_id}, {"$set": update_data})
        doc = await sub_col.find_one({"_id": sub_id})
        subscription = Subscription.model_validate(doc)
    else:
        subscription = Subscription(
            **{"_id": f"sub_{uuid4().hex}"},
            user_id=current_user.id,
            tenant_id=current_user.tenant_id,
            stripe_customer_id=stripe_customer_id,
            stripe_subscription_id=stripe_subscription_id,
            stripe_checkout_session_id=session_id,
            status=SubscriptionStatus.active,
            plan_id=plan_id,
            amount=plan_info["amount"],
            currency=plan_info["currency"],
            current_period_start=period_start,
            current_period_end=period_end,
        )
        await sub_col.insert_one(subscription.model_dump(by_alias=True))

    # Promote User to workspace_admin if they are currently student
    user_col = get_collection(current_user.tenant_id, USERS)
    user_patch: dict[str, Any] = {"subscription_id": subscription.id}
    if current_user.role == UserRole.student:
        user_patch["role"] = UserRole.workspace_admin.value
        current_user.role = UserRole.workspace_admin

    current_user.subscription_id = subscription.id
    current_user.touch()
    user_patch["updated_at"] = current_user.updated_at

    await user_col.update_one({"_id": current_user.id}, {"$set": user_patch})
    await invalidate_user_cache(current_user)

    # Activate Tenant subscription
    tenants_col = get_collection("platform", "tenants")
    await tenants_col.update_one(
        {"_id": current_user.tenant_id},
        {"$set": {"status": TenantStatus.active.value, "subscription_expires_at": period_end}},
    )

    logger.info(
        "Successfully verified subscription %s: user %s promoted to %s",
        subscription.id,
        current_user.id,
        current_user.role,
    )
    return subscription


async def get_user_subscription(user: User) -> Subscription | None:
    """Retrieve the current active or most recent subscription for a user."""
    sub_col = get_collection(user.tenant_id, SUBSCRIPTIONS)
    doc = await sub_col.find_one(
        {"user_id": user.id, "deleted_at": None},
        sort=[("created_at", -1)],
    )
    if doc is None:
        return None
    return Subscription.model_validate(doc)


async def handle_webhook_event(payload: bytes, sig_header: str | None) -> dict[str, Any]:
    """Process incoming Stripe webhook events."""
    if is_stripe_configured() and settings.stripe_webhook_secret and sig_header:
        stripe.api_key = settings.stripe_secret_key
        try:
            event = stripe.Webhook.construct_event(
                payload, sig_header, settings.stripe_webhook_secret
            )
        except Exception as exc:
            logger.error("Stripe webhook signature verification failed: %s", exc)
            raise BadRequestError(f"Webhook signature error: {exc}") from exc
    else:
        try:
            event = json.loads(payload.decode("utf-8"))
        except Exception as exc:
            raise BadRequestError(f"Invalid JSON payload: {exc}") from exc

    event_type = event.get("type", "")
    data_object = event.get("data", {}).get("object", {})
    logger.info("Processing Stripe webhook event: %s", event_type)

    if event_type == "checkout.session.completed":
        session_id = data_object.get("id")
        user_id = data_object.get("metadata", {}).get("user_id") or data_object.get("client_reference_id")
        tenant_id = data_object.get("metadata", {}).get("tenant_id")

        if user_id and tenant_id:
            user_col = get_collection(tenant_id, USERS)
            user_doc = await user_col.find_one({"_id": user_id, "deleted_at": None})
            if user_doc:
                user = User.model_validate(user_doc)
                await verify_checkout_session(session_id, user)

    elif event_type == "customer.subscription.deleted":
        sub_id = data_object.get("id")
        # Mark subscription canceled
        # In a real setup, tenant_id would be in subscription metadata
        metadata = data_object.get("metadata", {})
        tenant_id = metadata.get("tenant_id")
        if tenant_id:
            sub_col = get_collection(tenant_id, SUBSCRIPTIONS)
            await sub_col.update_one(
                {"stripe_subscription_id": sub_id},
                {"$set": {"status": SubscriptionStatus.canceled.value, "updated_at": utc_now()}},
            )

    return {"received": True, "event": event_type}
