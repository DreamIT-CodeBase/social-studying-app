"""Notification service — Sprint 5.7.

Single entry point for dispatching pushes. Picks a sender at startup
based on whether ANH credentials are configured, then exposes typed
helpers for every notification type the app fires (study reminder,
streak warning, milestone, unanswered re-prompt).

Sender selection
----------------
``settings.notification_hub_connection_string`` is the toggle:

* **Empty** (the default in local dev) → :class:`LoggingSender`. Every
  ``would have sent`` is logged and persisted to the dispatch log
  with outcome=``logged_only``. Nothing leaves the process.
* **Non-empty** (the deployed environments) →
  :class:`AzureNotificationHubSender`. Hits ANH's REST API with the
  installation-id-targeted endpoint so the push lands on the exact
  device the user registered, not every device in the namespace.

Switching senders at runtime
----------------------------
The factory caches the chosen sender so a request burst doesn't
re-parse the connection string per call. Tests use
:func:`set_sender_for_tests` to swap in a fake; production code never
constructs senders directly — always go through :func:`get_sender`.

Why no scheduled-notification table
-----------------------------------
The Sprint 5 design has a polling scheduler (see :mod:`app.workers.
notification_scheduler`) that computes who needs which reminder on
the fly from gamification state + workspace settings — same approach
as the per-tenant analytics aggregations. No queue, no per-user cron
rows. The append-only :class:`NotificationDispatch` log is the only
historical record; if the scheduler crashes between deciding and
sending, the next tick recomputes.
"""

from __future__ import annotations

import base64
import hashlib
import hmac
import json
import logging
import time
import urllib.parse
from abc import ABC, abstractmethod
from dataclasses import dataclass, field
from typing import Any
from uuid import uuid4

import httpx

from app.core.config import settings
from app.core.database import (
    NOTIFICATION_DISPATCHES,
    NOTIFICATION_TOKENS,
    get_collection,
)
from app.models.base import utc_now
from app.models.notification import (
    DevicePlatform,
    DispatchOutcome,
    NotificationDispatch,
    NotificationToken,
    NotificationType,
)

logger = logging.getLogger(__name__)


# ── Payload + result types ─────────────────────────────────────────────────


@dataclass(frozen=True, slots=True)
class NotificationPayload:
    """Everything a sender needs to fire one push.

    ``data`` lands on the Flutter side as the payload map — the
    foreground in-app banner reads ``type`` to decide what to render,
    and the tap handler reads e.g. ``workspace_id`` to deep-link. Keep
    keys flat strings; FCM's data payload is string→string.
    """

    notification_type: NotificationType
    title: str
    body: str
    data: dict[str, str] = field(default_factory=dict)


@dataclass(frozen=True, slots=True)
class DispatchResult:
    """What the sender returned. Mirrors :class:`DispatchOutcome`
    but carries the optional failure reason so the caller can log it
    without re-parsing strings.
    """

    outcome: DispatchOutcome
    failure_reason: str | None = None


# ── Sender abstraction ─────────────────────────────────────────────────────


class NotificationSender(ABC):
    """Pluggable push sender. Implementations are stateless beyond the
    transport client they hold — never store per-user state on a
    sender."""

    @abstractmethod
    async def send_to_installation(
        self,
        *,
        installation_id: str,
        platform: DevicePlatform,
        payload: NotificationPayload,
    ) -> DispatchResult:
        """Deliver one push to one device. Implementations MUST NOT
        raise on send failure — they return a :class:`DispatchResult`
        with outcome=``failed`` so the caller can persist the
        attempt."""


class LoggingSender(NotificationSender):
    """No-op sender. Logs at INFO and reports ``logged_only``.

    Used when ``settings.notification_hub_connection_string`` is empty
    — dev machines, CI, and any environment where the FCM key hasn't
    been pasted into ANH yet. Tests can construct one directly.
    """

    async def send_to_installation(
        self,
        *,
        installation_id: str,
        platform: DevicePlatform,
        payload: NotificationPayload,
    ) -> DispatchResult:
        logger.info(
            "[LoggingSender] would push installation=%s platform=%s "
            "type=%s title=%r body=%r data=%s",
            installation_id,
            platform.value,
            payload.notification_type.value,
            payload.title,
            payload.body,
            payload.data,
        )
        return DispatchResult(outcome=DispatchOutcome.logged_only)


class AzureNotificationHubSender(NotificationSender):
    """Real ANH sender — hits the ``/messages`` REST endpoint with
    installation-id targeting.

    The connection string parser, SAS token minter, and platform-
    specific payload shape live in private helpers. We hand-roll the
    SAS rather than pulling ``azure-mgmt-notificationhubs`` because
    the management SDK doesn't cover the data-plane push call (it's
    intended for hub provisioning, which Bicep already owns).

    Why installation-id targeting and not tag expressions
    -----------------------------------------------------
    Tag expressions ("send to everyone tagged ``user_<id>``") work for
    bulk pushes but waste a round-trip when we know exactly which
    install to ping. Installation IDs come from the Flutter client at
    registration time and are guaranteed unique per install — so the
    direct ``/installations/{id}/messages`` endpoint is the cheap path.
    """

    def __init__(
        self,
        *,
        connection_string: str,
        hub_name: str,
        http_client: httpx.AsyncClient | None = None,
    ) -> None:
        self._connection = _parse_connection_string(connection_string)
        self._hub_name = hub_name
        self._owned_client = http_client is None
        self._client = http_client or httpx.AsyncClient(timeout=10.0)

    async def aclose(self) -> None:
        """Close the underlying HTTP client if we own it. Tests that
        pass a shared client are expected to close it themselves."""
        if self._owned_client:
            await self._client.aclose()

    async def send_to_installation(
        self,
        *,
        installation_id: str,
        platform: DevicePlatform,
        payload: NotificationPayload,
    ) -> DispatchResult:
        endpoint = self._connection["endpoint"]
        url = (
            f"{endpoint}{self._hub_name}/messages/?direct&api-version=2015-01"
        )
        sas_token = _mint_sas_token(
            target_uri=f"{endpoint}{self._hub_name}/messages/",
            key_name=self._connection["key_name"],
            key_value=self._connection["key_value"],
            ttl_seconds=300,
        )
        body = _platform_payload(platform=platform, payload=payload)
        headers = {
            "Authorization": sas_token,
            "Content-Type": "application/json;charset=utf-8",
            "ServiceBusNotification-Format": _anh_format_for(platform),
            "ServiceBusNotification-DeviceHandle": installation_id,
        }
        try:
            response = await self._client.post(url, content=body, headers=headers)
        except httpx.HTTPError as exc:
            logger.warning(
                "ANH send failed at transport layer installation=%s err=%s",
                installation_id,
                exc,
            )
            return DispatchResult(
                outcome=DispatchOutcome.failed,
                failure_reason=f"transport: {exc}",
            )

        if 200 <= response.status_code < 300:
            return DispatchResult(outcome=DispatchOutcome.sent)
        # ANH returns 410 for an unknown / expired registration. That's a
        # cleanup signal — the caller (token registry) should delete the
        # row. We surface the status code in the failure reason so the
        # caller can branch on it.
        reason = f"http {response.status_code}: {response.text[:200]}"
        logger.warning(
            "ANH send rejected installation=%s status=%d body=%s",
            installation_id,
            response.status_code,
            response.text[:200],
        )
        return DispatchResult(
            outcome=DispatchOutcome.failed, failure_reason=reason
        )


# ── Sender factory ─────────────────────────────────────────────────────────


_cached_sender: NotificationSender | None = None


def get_sender() -> NotificationSender:
    """Return the process-wide sender, lazily constructing on first use.

    Honors the test-only override set via :func:`set_sender_for_tests`.
    """
    global _cached_sender
    if _cached_sender is not None:
        return _cached_sender
    if settings.notification_hub_connection_string and settings.notification_hub_name:
        _cached_sender = AzureNotificationHubSender(
            connection_string=settings.notification_hub_connection_string,
            hub_name=settings.notification_hub_name,
        )
        logger.info(
            "Notification sender: AzureNotificationHubSender (hub=%s)",
            settings.notification_hub_name,
        )
    else:
        _cached_sender = LoggingSender()
        logger.info("Notification sender: LoggingSender (no ANH creds configured)")
    return _cached_sender


def set_sender_for_tests(sender: NotificationSender | None) -> None:
    """Test-only — swap the cached sender. Pass ``None`` to reset and
    let the next :func:`get_sender` re-resolve from settings."""
    global _cached_sender
    _cached_sender = sender


# ── Public dispatch helpers ────────────────────────────────────────────────


async def dispatch_to_user(
    *,
    tenant_id: str,
    user_id: str,
    payload: NotificationPayload,
) -> list[DispatchResult]:
    """Send ``payload`` to every registered device for this user.

    Reads :class:`NotificationToken` rows from Cosmos, dispatches one
    push per row, and appends a :class:`NotificationDispatch` per
    attempt. Returns the per-token results so the caller can react
    (the scheduler treats a failure as non-fatal; an HTTP 410 from ANH
    triggers token cleanup via the caller's own discretion).
    """
    tokens = await _read_tokens(tenant_id=tenant_id, user_id=user_id)
    if not tokens:
        logger.info(
            "dispatch_to_user: no tokens user=%s type=%s",
            user_id,
            payload.notification_type.value,
        )
        return []

    sender = get_sender()
    timestamp = utc_now()
    results: list[DispatchResult] = []
    for token in tokens:
        result = await sender.send_to_installation(
            installation_id=token.installation_id,
            platform=token.platform,
            payload=payload,
        )
        results.append(result)
        await _record_dispatch(
            tenant_id=tenant_id,
            user_id=user_id,
            installation_id=token.installation_id,
            payload=payload,
            result=result,
            timestamp=timestamp,
        )
    return results


# ── Typed notification helpers ─────────────────────────────────────────────


async def send_milestone(
    *,
    tenant_id: str,
    user_id: str,
    workspace_id: str,
    title: str,
    body: str,
    badge_id: str | None = None,
    new_level: int | None = None,
) -> list[DispatchResult]:
    """Fire a milestone push — wired in from :mod:`gamification` on
    level-up or badge unlock. The Flutter side deep-links into the
    badges screen on tap.
    """
    data: dict[str, str] = {
        "type": NotificationType.milestone.value,
        "workspace_id": workspace_id,
    }
    if badge_id is not None:
        data["badge_id"] = badge_id
    if new_level is not None:
        data["new_level"] = str(new_level)
    return await dispatch_to_user(
        tenant_id=tenant_id,
        user_id=user_id,
        payload=NotificationPayload(
            notification_type=NotificationType.milestone,
            title=title,
            body=body,
            data=data,
        ),
    )


async def send_study_reminder(
    *,
    tenant_id: str,
    user_id: str,
    workspace_id: str,
    questions_per_day: int,
) -> list[DispatchResult]:
    """Daily nudge — "answer N questions today". Deep-links into the
    Study tab.
    """
    body = (
        "Answer one question to keep your streak going."
        if questions_per_day == 1
        else f"Answer {questions_per_day} questions to keep your streak going."
    )
    return await dispatch_to_user(
        tenant_id=tenant_id,
        user_id=user_id,
        payload=NotificationPayload(
            notification_type=NotificationType.study_reminder,
            title="Time to study!",
            body=body,
            data={
                "type": NotificationType.study_reminder.value,
                "workspace_id": workspace_id,
            },
        ),
    )


async def send_streak_warning(
    *,
    tenant_id: str,
    user_id: str,
    workspace_id: str,
    streak_days: int,
) -> list[DispatchResult]:
    """Same-day late-evening nudge sent when a student has an active
    streak that they're about to break by not studying today."""
    return await dispatch_to_user(
        tenant_id=tenant_id,
        user_id=user_id,
        payload=NotificationPayload(
            notification_type=NotificationType.streak_warning,
            title="Don't break your streak!",
            body=(
                f"You're on a {streak_days}-day streak. "
                "Answer one question before midnight to keep it alive."
            ),
            data={
                "type": NotificationType.streak_warning.value,
                "workspace_id": workspace_id,
                "streak_days": str(streak_days),
            },
        ),
    )


async def dispatch_gamification_milestones(
    *,
    tenant_id: str,
    user_id: str,
    workspace_id: str,
    leveled_up: bool,
    new_level: int,
    badges_unlocked: list[Any],
) -> None:
    """Fan-out helper called from the answer + flashcard background
    tasks. Fires one milestone push per discrete event (level-up + one
    per badge) — students who level up AND unlock a badge in the same
    answer get a push for each so the celebration tells the same
    story as the in-app overlay (Sprint 5.5).

    ``badges_unlocked`` is typed as ``list[Any]`` to avoid importing
    the gamification ``Badge`` model here and creating a cycle; in
    practice it's a list of :class:`app.models.gamification.Badge`.
    Each element must expose ``badge_id``, ``name``, and ``icon``.
    """
    if leveled_up:
        await send_milestone(
            tenant_id=tenant_id,
            user_id=user_id,
            workspace_id=workspace_id,
            title="Level up!",
            body=f"You reached Level {new_level}. Keep going!",
            new_level=new_level,
        )
    for badge in badges_unlocked:
        await send_milestone(
            tenant_id=tenant_id,
            user_id=user_id,
            workspace_id=workspace_id,
            title=f"Badge unlocked: {badge.name}",
            body=badge.description,
            badge_id=badge.badge_id,
        )


async def send_unanswered_reprompt(
    *,
    tenant_id: str,
    user_id: str,
    workspace_id: str,
    question_id: str,
    topic: str,
) -> list[DispatchResult]:
    """Sprint 5.12 — re-surface a question the student skipped earlier
    after its cool-down has elapsed."""
    return await dispatch_to_user(
        tenant_id=tenant_id,
        user_id=user_id,
        payload=NotificationPayload(
            notification_type=NotificationType.unanswered_reprompt,
            title="A question is waiting",
            body=f"Take another look at this {topic} question.",
            data={
                "type": NotificationType.unanswered_reprompt.value,
                "workspace_id": workspace_id,
                "question_id": question_id,
            },
        ),
    )


# ── Token CRUD ─────────────────────────────────────────────────────────────


async def register_token(
    *,
    tenant_id: str,
    user_id: str,
    installation_id: str,
    token: str,
    platform: DevicePlatform,
) -> NotificationToken:
    """Upsert a :class:`NotificationToken` by (user, installation).

    The Flutter app calls this on every cold start so a token rotation
    or app re-install converges within one launch. The doc id is
    deterministic from ``installation_id`` so a re-registration
    overwrites the same row (no orphaned duplicates).
    """
    timestamp = utc_now()
    # Deterministic id so the upsert filter and the doc agree on identity.
    # Hash the installation id to keep the id short + safe for Cosmos.
    doc_id = (
        f"ntk_{hashlib.sha256(installation_id.encode()).hexdigest()[:32]}"
    )
    doc = NotificationToken(
        **{"_id": doc_id},
        tenant_id=tenant_id,
        user_id=user_id,
        installation_id=installation_id,
        token=token,
        platform=platform,
        registered_at=timestamp,
        last_seen_at=timestamp,
    )
    col = get_collection(tenant_id, NOTIFICATION_TOKENS)
    # Read first so we can preserve the original ``registered_at`` on
    # a re-register. Only ``token`` + ``last_seen_at`` should churn on
    # the heartbeat path.
    existing = await col.find_one({"_id": doc_id, "deleted_at": None})
    if existing is not None:
        doc = doc.model_copy(
            update={"registered_at": existing.get("registered_at", timestamp)}
        )
    await col.replace_one(
        {"_id": doc_id},
        doc.model_dump(by_alias=True),
        upsert=True,
    )
    logger.info(
        "Registered notification token user=%s installation=%s platform=%s",
        user_id,
        installation_id,
        platform.value,
    )
    return doc


async def delete_token(
    *,
    tenant_id: str,
    user_id: str,
    installation_id: str,
) -> bool:
    """Soft-delete a single token. Returns ``True`` if a row was
    actually removed.

    Called on explicit sign-out from the Flutter side, and from the
    scheduler when ANH returns HTTP 410 (expired registration).
    """
    doc_id = (
        f"ntk_{hashlib.sha256(installation_id.encode()).hexdigest()[:32]}"
    )
    col = get_collection(tenant_id, NOTIFICATION_TOKENS)
    result = await col.update_one(
        {"_id": doc_id, "user_id": user_id, "deleted_at": None},
        {"$set": {"deleted_at": utc_now()}},
    )
    return result.modified_count > 0


# ── Cosmos reads / writes ──────────────────────────────────────────────────


async def _read_tokens(
    *, tenant_id: str, user_id: str
) -> list[NotificationToken]:
    col = get_collection(tenant_id, NOTIFICATION_TOKENS)
    cursor = col.find({"user_id": user_id, "deleted_at": None})
    return [NotificationToken.model_validate(raw) async for raw in cursor]


async def _record_dispatch(
    *,
    tenant_id: str,
    user_id: str,
    installation_id: str | None,
    payload: NotificationPayload,
    result: DispatchResult,
    timestamp: str,
) -> None:
    dispatch = NotificationDispatch(
        **{"_id": f"nd_{uuid4().hex}"},
        tenant_id=tenant_id,
        user_id=user_id,
        installation_id=installation_id,
        notification_type=payload.notification_type,
        title=payload.title,
        body=payload.body,
        outcome=result.outcome,
        failure_reason=result.failure_reason,
        dispatched_at=timestamp,
    )
    col = get_collection(tenant_id, NOTIFICATION_DISPATCHES)
    await col.insert_one(dispatch.model_dump(by_alias=True))


# ── Private helpers ────────────────────────────────────────────────────────


def _parse_connection_string(value: str) -> dict[str, str]:
    """Parse an ANH connection string into endpoint / key name / key value.

    Format: ``Endpoint=sb://...;SharedAccessKeyName=...;SharedAccessKey=...``.
    Normalises the endpoint to ``https://...`` because ANH's REST API
    lives over HTTPS even though the connection string advertises
    ``sb://`` (Service Bus protocol).
    """
    pairs: dict[str, str] = {}
    for part in value.split(";"):
        if "=" not in part:
            continue
        key, val = part.split("=", 1)
        pairs[key.strip()] = val.strip()
    endpoint = pairs.get("Endpoint", "")
    if endpoint.startswith("sb://"):
        endpoint = "https://" + endpoint[len("sb://") :]
    if not endpoint.endswith("/"):
        endpoint = endpoint + "/"
    return {
        "endpoint": endpoint,
        "key_name": pairs.get("SharedAccessKeyName", ""),
        "key_value": pairs.get("SharedAccessKey", ""),
    }


def _mint_sas_token(
    *,
    target_uri: str,
    key_name: str,
    key_value: str,
    ttl_seconds: int,
) -> str:
    """Build a SAS Authorization header value for an ANH REST call.

    See https://learn.microsoft.com/azure/notification-hubs/notification-hubs-push-notification-fixed-registrations
    — the standard SB-style SAS shape: URL-encoded target URI + UNIX
    expiry + HMAC-SHA256 signature.
    """
    expiry = int(time.time() + ttl_seconds)
    encoded_uri = urllib.parse.quote_plus(target_uri)
    string_to_sign = f"{encoded_uri}\n{expiry}"
    signature = base64.b64encode(
        hmac.new(
            key_value.encode("utf-8"),
            string_to_sign.encode("utf-8"),
            hashlib.sha256,
        ).digest()
    )
    encoded_signature = urllib.parse.quote_plus(signature)
    return (
        f"SharedAccessSignature sr={encoded_uri}&sig={encoded_signature}"
        f"&se={expiry}&skn={key_name}"
    )


def _anh_format_for(platform: DevicePlatform) -> str:
    """Header value ANH expects for the platform-specific payload shape."""
    return "gcm" if platform == DevicePlatform.android else "apple"


def _platform_payload(
    *, platform: DevicePlatform, payload: NotificationPayload
) -> bytes:
    """Return the platform-shaped JSON body that ANH proxies to FCM /
    APNs.

    FCM uses ``{ "data": {...}, "notification": {...} }``. APNs uses
    ``{ "aps": {...}, ...data }``. Keeping both shapes here means the
    sender doesn't bloat with platform conditionals at the call site.
    """
    if platform == DevicePlatform.android:
        body: dict[str, Any] = {
            "notification": {
                "title": payload.title,
                "body": payload.body,
            },
            "data": payload.data,
        }
    else:  # APNs
        body = {
            "aps": {
                "alert": {"title": payload.title, "body": payload.body},
                "sound": "default",
            },
            **payload.data,
        }
    return json.dumps(body).encode("utf-8")


# Re-exported for tests that want to assert the format selection
# without exercising a full sender.
__all__ = [
    "AzureNotificationHubSender",
    "DispatchResult",
    "LoggingSender",
    "NotificationPayload",
    "NotificationSender",
    "delete_token",
    "dispatch_gamification_milestones",
    "dispatch_to_user",
    "get_sender",
    "register_token",
    "send_milestone",
    "send_streak_warning",
    "send_study_reminder",
    "send_unanswered_reprompt",
    "set_sender_for_tests",
]
