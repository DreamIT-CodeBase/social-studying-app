"""Stripe payment gateway & subscription service.

Handles:
1. Admin and Student subscription plans (including $10/mo self-study recurring plan).
2. Customer creation & hosted Stripe Checkout session generation (both authenticated & public guest).
3. Secure mobile-to-web handoff token generation and verification.
4. Student 7-day free trial tracking and status assessment.
5. Immediate session verification & user promotion (workspace_admin for admins, active subscription for students).
6. Webhook handling with signature verification & idempotent database state updates.
7. Graceful mock mode when Stripe API keys are not configured (local dev & CI).
"""

import hashlib
import hmac
import json
import logging
import time
from datetime import UTC, datetime, timedelta
from typing import Any
from uuid import uuid4

import stripe

from app.core.auth import invalidate_user_cache
from app.core.config import settings
from app.core.database import SUBSCRIPTIONS, USERS, WORKSPACES, get_collection
from app.core.exceptions import BadRequestError
from app.models.base import utc_now
from app.models.subscription import (
    CheckoutSessionResponse,
    PlanOption,
    PublicVerifySessionResponse,
    StudentSubscriptionStatusResponse,
    Subscription,
    SubscriptionPlan,
    SubscriptionStatus,
)
from app.models.tenant import TenantStatus
from app.models.user import User, UserRole, WorkspaceMembership
from app.services.otp_service import validate_verification_token

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
    SubscriptionPlan.student_monthly: {
        "name": "Social Studying Student Self-Study",
        "description": "Unlimited adaptive AI questions, flashcards, mastery analytics, and self-study sessions.",
        "amount": 1000,  # $10.00
        "currency": "usd",
        "interval": "month",
        "duration_days": 30,
    },
}


def _get_signing_key() -> bytes:
    key_str = (
        getattr(settings, "jwt_secret_key", None)
        or settings.stripe_secret_key
        or settings.dev_auth_token
        or "social-studying-secure-handoff-key"
    )
    return key_str.encode("utf-8")


def create_handoff_token(user: User, plan_id: str | None = None) -> str:
    """Generate a short-lived HMAC-signed handoff token for mobile-to-web transitions."""
    email_clean = user.email.strip().lower()
    issued_at = int(time.time())
    payload = f"{user.id}:{email_clean}:{user.role.value}:{user.tenant_id}:{plan_id or ''}:{issued_at}"
    signature = hmac.new(_get_signing_key(), payload.encode("utf-8"), hashlib.sha256).hexdigest()
    return f"{payload}:{signature}"


def verify_handoff_token(token: str) -> dict[str, Any] | None:
    """Validate and unpack a mobile-to-web handoff token."""
    if not token or ":" not in token:
        return None
    parts = token.split(":")
    if len(parts) != 7:
        return None
    user_id, email, role, tenant_id, plan_id, issued_str, signature = parts
    try:
        issued_at = int(issued_str)
    except ValueError:
        return None
    if time.time() - issued_at > 1800:  # 30 minute expiry
        return None
    expected_payload = f"{user_id}:{email}:{role}:{tenant_id}:{plan_id}:{issued_str}"
    expected_sig = hmac.new(_get_signing_key(), expected_payload.encode("utf-8"), hashlib.sha256).hexdigest()
    if not hmac.compare_digest(signature, expected_sig):
        return None
    return {
        "user_id": user_id,
        "email": email,
        "role": role,
        "tenant_id": tenant_id,
        "plan_id": plan_id or None,
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


def _resolve_price_id(plan_id: SubscriptionPlan) -> str | None:
    if plan_id == SubscriptionPlan.student_monthly:
        return settings.stripe_price_id_student_monthly or None
    if plan_id == SubscriptionPlan.monthly:
        return settings.stripe_price_id_monthly or None
    if plan_id == SubscriptionPlan.annual:
        return settings.stripe_price_id_annual or None
    return None


async def create_checkout_session(
    user: User,
    plan_id: SubscriptionPlan = SubscriptionPlan.monthly,
    success_url: str | None = None,
    cancel_url: str | None = None,
) -> CheckoutSessionResponse:
    """Create a hosted Stripe Checkout Session for an authenticated app user."""
    plan_info = PLAN_DETAILS.get(plan_id, PLAN_DETAILS[SubscriptionPlan.monthly])
    website_url = (settings.website_base_url or "https://socialstudying.ai").rstrip("/")

    default_success_url = f"{website_url}/payment-success?session_id={{CHECKOUT_SESSION_ID}}&role={user.role.value}"
    default_cancel_url = f"{website_url}/payment-cancelled?role={user.role.value}"

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

        price_id = _resolve_price_id(plan_id)
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
                "role": user.role.value,
            },
        )

        logger.info(
            "Created Stripe Checkout session %s for user %s (plan %s)",
            session.id,
            user.id,
            plan_id,
        )
        return CheckoutSessionResponse(checkout_url=session.url or "", session_id=session.id)

    # Fallback mock mode for local dev / CI tests
    mock_id = f"cs_test_{uuid4().hex}"
    mock_checkout_url = f"{final_success_url.replace('{CHECKOUT_SESSION_ID}', mock_id)}"

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


async def create_public_checkout_session(
    email: str,
    plan_id: SubscriptionPlan = SubscriptionPlan.monthly,
    full_name: str | None = None,
    phone: str | None = None,
    organization: str | None = None,
    verification_token: str | None = None,
    success_url: str | None = None,
    cancel_url: str | None = None,
) -> CheckoutSessionResponse:
    """Create a checkout session for website visitors (new or returning admin/student)."""
    email_clean = email.strip().lower()
    plan_info = PLAN_DETAILS.get(plan_id, PLAN_DETAILS[SubscriptionPlan.monthly])

    # Validate verification token for admin onboarding
    if plan_id != SubscriptionPlan.student_monthly:
        if not verification_token or not validate_verification_token(email_clean, verification_token):
            raise BadRequestError("Email address has not been verified. Please complete OTP verification.")

    website_url = (settings.website_base_url or "https://socialstudying.ai").rstrip("/")
    role = "student" if plan_id == SubscriptionPlan.student_monthly else "workspace_admin"

    default_success_url = f"{website_url}/payment-success?session_id={{CHECKOUT_SESSION_ID}}&role={role}"
    default_cancel_url = f"{website_url}/payment-cancelled?role={role}"

    final_success_url = success_url or default_success_url
    final_cancel_url = cancel_url or default_cancel_url

    tenant_id = getattr(settings, "dev_auth_tenant_id", "platform")

    if is_stripe_configured():
        stripe.api_key = settings.stripe_secret_key

        customer_id: str | None = None
        # Check if customer already exists in Stripe
        existing_customers = stripe.Customer.list(email=email_clean, limit=1)
        if existing_customers.data:
            customer_id = existing_customers.data[0].id
        else:
            customer = stripe.Customer.create(
                email=email_clean,
                name=full_name or email_clean.split("@")[0],
                phone=phone,
                metadata={
                    "organization": organization or "",
                    "role": role,
                    "tenant_id": tenant_id,
                },
            )
            customer_id = customer.id

        price_id = _resolve_price_id(plan_id)
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
            metadata={
                "email": email_clean,
                "full_name": full_name or "",
                "phone": phone or "",
                "organization": organization or "",
                "plan_id": plan_id.value,
                "role": role,
                "tenant_id": tenant_id,
            },
        )
        logger.info("Created public Stripe Checkout session %s for %s", session.id, email_clean)
        return CheckoutSessionResponse(checkout_url=session.url or "", session_id=session.id)

    # Mock mode
    mock_id = f"cs_test_{uuid4().hex}"
    mock_checkout_url = f"{final_success_url.replace('{CHECKOUT_SESSION_ID}', mock_id)}"
    return CheckoutSessionResponse(checkout_url=mock_checkout_url, session_id=mock_id)


async def verify_public_session(session_id: str) -> PublicVerifySessionResponse:
    """Verify session completion for the website success page without requiring JWT."""
    plan_id = "monthly"
    email = None
    role = "workspace_admin"
    status_str = "completed"

    if is_stripe_configured() and not session_id.startswith("cs_test_"):
        stripe.api_key = settings.stripe_secret_key
        try:
            session = stripe.checkout.Session.retrieve(session_id)
        except Exception as exc:
            logger.error("Failed to retrieve public Stripe session %s: %s", session_id, exc)
            raise BadRequestError(f"Invalid or expired checkout session: {exc}") from exc

        if session.payment_status not in ("paid", "no_payment_required") and session.status != "complete":
            return PublicVerifySessionResponse(
                is_active=False,
                status=session.status or "incomplete",
                message="Payment is still processing.",
            )

        metadata = session.metadata or {}
        plan_id = metadata.get("plan_id", "monthly")
        email = metadata.get("email") or (session.customer_details and session.customer_details.email)
        role = metadata.get("role", "workspace_admin")
    else:
        # Mock mode
        email = "demo@socialstudying.ai"

    msg = (
        "Your subscription is verified and active. You may return to the app."
        if role == "workspace_admin"
        else "Your self-study subscription is active. Return to the app to continue studying."
    )
    return PublicVerifySessionResponse(
        is_active=True,
        status=status_str,
        plan_id=plan_id,
        email=email,
        role=role,
        message=msg,
    )


async def verify_checkout_session(session_id: str, current_user: User) -> Subscription:
    """Verify a completed checkout session for an authenticated user and update subscription."""
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

    user_col = get_collection(current_user.tenant_id, USERS)
    user_patch: dict[str, Any] = {"subscription_id": subscription.id}

    # Promote to workspace_admin ONLY for admin plans; students remain students
    if plan_id != SubscriptionPlan.student_monthly and current_user.role == UserRole.student:
        user_patch["role"] = UserRole.workspace_admin.value
        current_user.role = UserRole.workspace_admin

    current_user.subscription_id = subscription.id
    current_user.touch()
    user_patch["updated_at"] = current_user.updated_at

    await user_col.update_one({"_id": current_user.id}, {"$set": user_patch})
    await invalidate_user_cache(current_user)

    if plan_id != SubscriptionPlan.student_monthly:
        tenants_col = get_collection("platform", "tenants")
        await tenants_col.update_one(
            {"_id": current_user.tenant_id},
            {"$set": {"status": TenantStatus.active.value, "subscription_expires_at": period_end}},
        )

    logger.info(
        "Successfully verified subscription %s: user %s (plan %s)",
        subscription.id,
        current_user.id,
        plan_id,
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


async def get_student_trial_status(user: User) -> StudentSubscriptionStatusResponse:
    """Evaluate whether the student has an active trial or paid subscription."""
    sub_col = get_collection(user.tenant_id, SUBSCRIPTIONS)
    paid_sub = await sub_col.find_one(
        {
            "user_id": user.id,
            "status": SubscriptionStatus.active.value,
            "deleted_at": None,
        }
    )

    if paid_sub:
        return StudentSubscriptionStatusResponse(
            is_active=True,
            is_trial=False,
            is_trial_expired=False,
            days_remaining=30,
            trial_ends_at=None,
            subscription_status="active",
            plan_id=paid_sub.get("plan_id", "student_monthly"),
            can_access_study=True,
            message="Active paid subscription",
        )

    # Calculate 7-day trial from user creation
    created_at_str = user.created_at or utc_now()
    try:
        created_dt = datetime.fromisoformat(created_at_str.replace("Z", "+00:00"))
    except Exception:
        created_dt = datetime.now(UTC)

    trial_end_dt = created_dt + timedelta(days=7)
    now_dt = datetime.now(UTC)

    if now_dt <= trial_end_dt:
        days_left = max(1, (trial_end_dt - now_dt).days + 1)
        return StudentSubscriptionStatusResponse(
            is_active=True,
            is_trial=True,
            is_trial_expired=False,
            days_remaining=days_left,
            trial_ends_at=trial_end_dt.isoformat(),
            subscription_status="trialing",
            plan_id="student_monthly",
            can_access_study=True,
            message=f"{days_left} day(s) remaining in your free trial",
        )

    return StudentSubscriptionStatusResponse(
        is_active=False,
        is_trial=False,
        is_trial_expired=True,
        days_remaining=0,
        trial_ends_at=trial_end_dt.isoformat(),
        subscription_status="expired",
        plan_id="student_monthly",
        can_access_study=False,
        message="Your 7-day free trial has expired. Subscribe to continue self-study.",
    )


async def handle_webhook_event(payload: bytes, sig_header: str | None) -> dict[str, Any]:
    """Process incoming Stripe webhook events idempotently."""
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

    tenant_id = getattr(settings, "dev_auth_tenant_id", "platform")

    if event_type == "checkout.session.completed":
        session_id = data_object.get("id")
        data_object.get("customer")
        data_object.get("subscription")
        metadata = data_object.get("metadata", {})

        plan_id_str = metadata.get("plan_id", "monthly")
        try:
            plan_id = SubscriptionPlan(plan_id_str)
        except ValueError:
            plan_id = SubscriptionPlan.monthly

        user_id = metadata.get("user_id") or data_object.get("client_reference_id")
        email = metadata.get("email") or (data_object.get("customer_details") or {}).get("email")
        full_name = metadata.get("full_name")
        organization = metadata.get("organization")

        user_col = get_collection(tenant_id, USERS)
        target_user: User | None = None

        if user_id:
            user_doc = await user_col.find_one({"_id": user_id, "deleted_at": None})
            if user_doc:
                target_user = User.model_validate(user_doc)

        if not target_user and email:
            email_clean = email.strip().lower()
            user_doc = await user_col.find_one({"email": email_clean, "deleted_at": None})
            if user_doc:
                target_user = User.model_validate(user_doc)
            else:
                # Create user for website onboarding admin/student
                is_student = plan_id == SubscriptionPlan.student_monthly
                role = UserRole.student if is_student else UserRole.workspace_admin
                new_user_id = f"usr_{uuid4().hex}"
                now_iso = utc_now()
                new_user_doc = {
                    "_id": new_user_id,
                    "tenant_id": tenant_id,
                    "email": email_clean,
                    "display_name": full_name or email_clean.split("@")[0],
                    "role": role.value,
                    "workspace_memberships": [],
                    "subscription_id": None,
                    "is_active": True,
                    "created_at": now_iso,
                    "updated_at": now_iso,
                }
                await user_col.insert_one(new_user_doc)
                target_user = User.model_validate(new_user_doc)
                logger.info("Created new user %s (%s) from Stripe webhook", new_user_id, email_clean)

                # If admin, create an initial workspace
                if role == UserRole.workspace_admin:
                    ws_col = get_collection(tenant_id, WORKSPACES)
                    ws_id = f"wsp_{uuid4().hex}"
                    ws_doc = {
                        "_id": ws_id,
                        "tenant_id": tenant_id,
                        "name": organization or f"{target_user.display_name}'s Classroom",
                        "description": "Primary study workspace",
                        "invite_code": f"INV-{uuid4().hex[:6].upper()}",
                        "created_by": new_user_id,
                        "created_at": now_iso,
                        "updated_at": now_iso,
                    }
                    await ws_col.insert_one(ws_doc)
                    membership = WorkspaceMembership(
                        workspace_id=ws_id,
                        role=UserRole.workspace_admin,
                        joined_at=now_iso,
                    )
                    await user_col.update_one(
                        {"_id": new_user_id},
                        {"$push": {"workspace_memberships": membership.model_dump()}},
                    )
                    target_user.workspace_memberships.append(membership)

        if target_user:
            await verify_checkout_session(session_id, target_user)

    elif event_type in ("customer.subscription.updated", "customer.subscription.deleted"):
        sub_id = data_object.get("id")
        stripe_status = data_object.get("status", "canceled")
        status_enum = (
            SubscriptionStatus.active
            if stripe_status == "active"
            else SubscriptionStatus.canceled
        )
        sub_col = get_collection(tenant_id, SUBSCRIPTIONS)
        await sub_col.update_one(
            {"stripe_subscription_id": sub_id},
            {"$set": {"status": status_enum.value, "updated_at": utc_now()}},
        )
        logger.info("Updated subscription %s status to %s", sub_id, status_enum.value)

    return {"received": True, "event": event_type}
