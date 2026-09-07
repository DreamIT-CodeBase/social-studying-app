"""Subscription & Stripe checkout endpoints.

Handles:
1. Fetching available plans and current user's subscription status.
2. Generating hosted Stripe Checkout sessions for subscription purchase.
3. Verifying completed checkout sessions and promoting users to workspace_admin.
4. Handling inbound Stripe webhook events.
"""

from typing import Any

from fastapi import APIRouter, Depends, Header, Request, status

from app.core.auth import get_current_user
from app.models.subscription import (
    CheckoutSessionResponse,
    CreateCheckoutSessionRequest,
    PlanOption,
    SubscriptionMeResponse,
    SubscriptionResponse,
    SubscriptionStatus,
    VerifySessionRequest,
)
from app.models.user import User, UserRole
from app.services import stripe_service

router = APIRouter(prefix="/subscriptions", tags=["subscriptions"])


@router.get("/plans", response_model=list[PlanOption])
async def get_plans() -> list[PlanOption]:
    """List available subscription plans."""
    return stripe_service.get_available_plans()


@router.get("/me", response_model=SubscriptionMeResponse)
async def get_my_subscription(
    current_user: User = Depends(get_current_user),
) -> SubscriptionMeResponse:
    """Check whether the authenticated user has an active admin subscription."""
    sub = await stripe_service.get_user_subscription(current_user)
    has_active = False
    sub_response = None

    if sub:
        has_active = sub.status in (SubscriptionStatus.active, SubscriptionStatus.trialing)
        sub_response = SubscriptionResponse.from_doc(sub)
    elif current_user.role in (UserRole.workspace_admin, UserRole.tenant_admin):
        # Admins created before or granted by tenant owner
        has_active = True

    return SubscriptionMeResponse(
        has_active_subscription=has_active,
        role=current_user.role.value,
        subscription=sub_response,
        available_plans=stripe_service.get_available_plans(),
    )


@router.post(
    "/checkout-session",
    response_model=CheckoutSessionResponse,
    status_code=status.HTTP_201_CREATED,
)
async def create_checkout_session(
    body: CreateCheckoutSessionRequest,
    current_user: User = Depends(get_current_user),
) -> CheckoutSessionResponse:
    """Create a hosted Stripe Checkout session to purchase an admin subscription."""
    return await stripe_service.create_checkout_session(
        user=current_user,
        plan_id=body.plan_id,
        success_url=body.success_url,
        cancel_url=body.cancel_url,
    )


@router.post("/verify-session", response_model=SubscriptionResponse)
async def verify_session(
    body: VerifySessionRequest,
    current_user: User = Depends(get_current_user),
) -> SubscriptionResponse:
    """Verify session completion on mobile app return, promoting user to workspace_admin."""
    sub = await stripe_service.verify_checkout_session(
        session_id=body.session_id,
        current_user=current_user,
    )
    return SubscriptionResponse.from_doc(sub)


@router.post("/webhook")
async def stripe_webhook(
    request: Request,
    stripe_signature: str | None = Header(None, alias="stripe-signature"),
) -> dict[str, Any]:
    """Public webhook receiver for asynchronous Stripe events."""
    payload = await request.body()
    return await stripe_service.handle_webhook_event(payload, stripe_signature)
