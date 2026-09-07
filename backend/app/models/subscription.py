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


class CheckoutSessionResponse(BaseModel):
    checkout_url: str
    session_id: str


class VerifySessionRequest(BaseModel):
    session_id: str


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
