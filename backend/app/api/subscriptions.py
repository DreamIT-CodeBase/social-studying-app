"""Subscription & Stripe checkout endpoints.

Handles:
1. Fetching available plans and current user's subscription status.
2. Generating hosted Stripe Checkout sessions for authenticated app users and website onboarding users.
3. Sending and verifying 6-digit email OTPs for admin registration.
4. Mobile-to-website handoff token generation.
5. Student 7-day free trial and paid subscription status checks.
6. Public and authenticated session verification.
7. Inbound Stripe webhook handling with signature verification.
"""

from typing import Any

from fastapi import APIRouter, Depends, Header, Query, Request, status

from app.core.auth import get_current_user
from app.core.config import settings
from app.models.subscription import (
    CheckoutSessionResponse,
    CreateCheckoutSessionRequest,
    HandoffTokenResponse,
    PlanOption,
    PublicCheckoutSessionRequest,
    PublicVerifySessionResponse,
    SendEmailOtpRequest,
    SendEmailOtpResponse,
    StudentSubscriptionStatusResponse,
    SubscriptionMeResponse,
    SubscriptionPlan,
    SubscriptionResponse,
    SubscriptionStatus,
    VerifyEmailOtpRequest,
    VerifyEmailOtpResponse,
    VerifySessionRequest,
)
from app.models.user import User, UserRole
from app.services import otp_service, stripe_service

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
        has_active = True

    return SubscriptionMeResponse(
        has_active_subscription=has_active,
        role=current_user.role.value,
        subscription=sub_response,
        available_plans=stripe_service.get_available_plans(),
    )


@router.get("/student/status", response_model=StudentSubscriptionStatusResponse)
async def get_student_status(
    current_user: User = Depends(get_current_user),
) -> StudentSubscriptionStatusResponse:
    """Check the student's 7-day free trial or paid subscription status."""
    return await stripe_service.get_student_trial_status(current_user)


@router.post("/send-email-otp", response_model=SendEmailOtpResponse)
async def send_email_otp(body: SendEmailOtpRequest) -> SendEmailOtpResponse:
    """Send a single-use 6-digit verification code to an email address."""
    result = await otp_service.send_email_otp(body.email)
    return SendEmailOtpResponse(
        message=result["message"],
        expires_in_seconds=result["expires_in_seconds"],
    )


@router.post("/verify-email-otp", response_model=VerifyEmailOtpResponse)
async def verify_email_otp(body: VerifyEmailOtpRequest) -> VerifyEmailOtpResponse:
    """Verify an input OTP and return a tamper-proof verification token."""
    token = await otp_service.verify_email_otp(body.email, body.otp)
    return VerifyEmailOtpResponse(
        verified=True,
        verification_token=token,
        message="Email successfully verified.",
    )


@router.post("/handoff-token", response_model=HandoffTokenResponse)
async def generate_handoff_token(
    current_user: User = Depends(get_current_user),
    plan_id: SubscriptionPlan | None = Query(None),
) -> HandoffTokenResponse:
    """Generate a secure signed token to transition an authenticated mobile user to the website."""
    token = stripe_service.create_handoff_token(
        current_user, plan_id.value if plan_id else None
    )
    website_url = (settings.website_base_url or "https://socialstudying.ai").rstrip("/")
    if current_user.role == UserRole.student or plan_id == SubscriptionPlan.student_monthly:
        redirect = f"{website_url}/student-subscribe?email={current_user.email}&token={token}"
    else:
        redirect = f"{website_url}/subscribe?email={current_user.email}&token={token}"

    return HandoffTokenResponse(
        handoff_token=token,
        redirect_url=redirect,
        expires_in_seconds=1800,
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
    """Create a hosted Stripe Checkout session for an authenticated user."""
    return await stripe_service.create_checkout_session(
        user=current_user,
        plan_id=body.plan_id,
        success_url=body.success_url,
        cancel_url=body.cancel_url,
    )


@router.post(
    "/public/checkout-session",
    response_model=CheckoutSessionResponse,
    status_code=status.HTTP_201_CREATED,
)
async def create_public_checkout_session(
    body: PublicCheckoutSessionRequest,
) -> CheckoutSessionResponse:
    """Create a hosted Stripe Checkout session for website onboarding."""
    return await stripe_service.create_public_checkout_session(
        email=body.email,
        plan_id=body.plan_id,
        full_name=body.full_name,
        phone=body.phone,
        organization=body.organization,
        verification_token=body.verification_token,
        success_url=body.success_url,
        cancel_url=body.cancel_url,
    )


@router.post("/verify-session", response_model=SubscriptionResponse)
async def verify_session(
    body: VerifySessionRequest,
    current_user: User = Depends(get_current_user),
) -> SubscriptionResponse:
    """Verify session completion for an authenticated app user."""
    sub = await stripe_service.verify_checkout_session(
        session_id=body.session_id,
        current_user=current_user,
    )
    return SubscriptionResponse.from_doc(sub)


@router.get("/verify-session-public", response_model=PublicVerifySessionResponse)
async def verify_session_public(
    session_id: str = Query(..., description="Stripe checkout session ID"),
) -> PublicVerifySessionResponse:
    """Verify session completion for the website success landing page."""
    return await stripe_service.verify_public_session(session_id)


@router.post("/webhook")
async def stripe_webhook(
    request: Request,
    stripe_signature: str | None = Header(None, alias="stripe-signature"),
) -> dict[str, Any]:
    """Public webhook receiver for asynchronous Stripe events."""
    payload = await request.body()
    return await stripe_service.handle_webhook_event(payload, stripe_signature)
