"""Subscription model — stored in Cosmos DB, 'subscriptions' collection."""

from enum import StrEnum

from pydantic import BaseModel, Field

from app.models.base import CosmosDocument


class SubscriptionStatus(StrEnum):
    active = "active"
    trialing = "trialing"
    past_due = "past_due"
    canceled = "canceled"
    incomplete = "incomplete"
    incomplete_expired = "incomplete_expired"


class SubscriptionPlan(StrEnum):
    monthly = "monthly"
    annual = "annual"
    pro_admin = "pro_admin"
    student_monthly = "student_monthly"


class Subscription(CosmosDocument):
    """Stored in the platform/tenant database, 'subscriptions' collection."""

    user_id: str
    tenant_id: str
    stripe_customer_id: str
    stripe_subscription_id: str | None = None
    stripe_checkout_session_id: str | None = None
    status: SubscriptionStatus = SubscriptionStatus.active
    plan_id: SubscriptionPlan = SubscriptionPlan.monthly
    amount: int = 1900  # in cents ($19.00 default)
    currency: str = "usd"
    current_period_start: str | None = None
    current_period_end: str | None = None
    cancel_at_period_end: bool = False


# ── Request / Response schemas ────────────────────────────────────────────────


class CreateCheckoutSessionRequest(BaseModel):
    plan_id: SubscriptionPlan = SubscriptionPlan.monthly
    success_url: str | None = None
    cancel_url: str | None = None


class PublicCheckoutSessionRequest(BaseModel):
    plan_id: SubscriptionPlan = SubscriptionPlan.monthly
    email: str
    full_name: str | None = None
    phone: str | None = None
    organization: str | None = None
    verification_token: str | None = None
    success_url: str | None = None
    cancel_url: str | None = None


class CheckoutSessionResponse(BaseModel):
    checkout_url: str
    session_id: str


class VerifySessionRequest(BaseModel):
    session_id: str


class PublicVerifySessionResponse(BaseModel):
    is_active: bool
    status: str
    plan_id: str | None = None
    email: str | None = None
    role: str | None = None
    message: str


class SendEmailOtpRequest(BaseModel):
    email: str


class SendEmailOtpResponse(BaseModel):
    message: str
    expires_in_seconds: int = 600


class VerifyEmailOtpRequest(BaseModel):
    email: str
    otp: str


class VerifyEmailOtpResponse(BaseModel):
    verified: bool
    verification_token: str
    message: str


class HandoffTokenResponse(BaseModel):
    handoff_token: str
    redirect_url: str
    expires_in_seconds: int = 900


class StudentSubscriptionStatusResponse(BaseModel):
    is_active: bool
    is_trial: bool
    is_trial_expired: bool
    days_remaining: int
    trial_ends_at: str | None = None
    subscription_status: str | None = None
    plan_id: str | None = None
    can_access_study: bool
    message: str


class SubscriptionResponse(BaseModel):
    id: str
    user_id: str
    tenant_id: str
    stripe_customer_id: str
    stripe_subscription_id: str | None
    status: SubscriptionStatus
    plan_id: SubscriptionPlan
    amount: int
    currency: str
    current_period_start: str | None
    current_period_end: str | None
    cancel_at_period_end: bool
    created_at: str

    @classmethod
    def from_doc(cls, doc: Subscription) -> "SubscriptionResponse":
        return cls(
            id=doc.id,
            user_id=doc.user_id,
            tenant_id=doc.tenant_id,
            stripe_customer_id=doc.stripe_customer_id,
            stripe_subscription_id=doc.stripe_subscription_id,
            status=doc.status,
            plan_id=doc.plan_id,
            amount=doc.amount,
            currency=doc.currency,
            current_period_start=doc.current_period_start,
            current_period_end=doc.current_period_end,
            cancel_at_period_end=doc.cancel_at_period_end,
            created_at=doc.created_at,
        )


class PlanOption(BaseModel):
    plan_id: SubscriptionPlan
    name: str
    description: str
    amount: int
    currency: str
    interval: str


class SubscriptionMeResponse(BaseModel):
    has_active_subscription: bool
    role: str
    subscription: SubscriptionResponse | None = None
    available_plans: list[PlanOption] = Field(default_factory=list)
