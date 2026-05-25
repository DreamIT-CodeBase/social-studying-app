"""Notification models — Sprint 5.7.

Two persisted shapes:

- :class:`NotificationToken` — one row per (user, installation). The
  Flutter app's :class:`NotificationService` registers a fresh FCM
  token on every cold start; the backend upserts by ``installation_id``
  so a re-install replaces the old token instead of duplicating it.
- :class:`NotificationDispatch` — append-only log of every push the
  service has sent (or attempted). Lets us reconstruct delivery
  history for debugging without scraping ANH's own activity log.

The body shape sent over the wire (the actual push payload) is a
plain dataclass defined alongside the sender, not a Cosmos model —
:class:`NotificationPayload` in ``services/notifications.py``.
"""

from enum import StrEnum

from app.models.base import CosmosDocument


class DevicePlatform(StrEnum):
    """Platforms the app ships to. ANH uses these as tags so we can
    target a single platform on a push."""

    android = "android"
    ios = "ios"


class NotificationType(StrEnum):
    """Wire ``type`` field on every push payload.

    The Flutter side branches on this when the user taps the
    notification — e.g. ``study_reminder`` lands on the Study tab,
    ``milestone`` opens the badges screen.
    """

    study_reminder = "study_reminder"
    streak_warning = "streak_warning"
    milestone = "milestone"
    unanswered_reprompt = "unanswered_reprompt"


class NotificationToken(CosmosDocument):
    """One device's push registration.

    Partition key: ``user_id``. Stored in the per-tenant database,
    ``notification_tokens`` collection.

    Uniqueness is (user_id, installation_id) — the Flutter app
    generates a per-install UUID and re-registers on every cold start,
    so re-installs replace rather than dupe. ``token`` may rotate
    silently (FCM rotates without notice); the upsert keeps the row
    pinned to the installation and just updates the token.
    """

    tenant_id: str
    user_id: str
    installation_id: str
    token: str
    platform: DevicePlatform
    registered_at: str       # ISO 8601 UTC
    last_seen_at: str        # ISO 8601 UTC, bumped on each register call


class DispatchOutcome(StrEnum):
    """What happened when the service tried to send a push.

    ``logged_only`` covers dev / missing-creds environments where the
    :class:`LoggingSender` is wired up — the payload is recorded but
    no live call goes out.
    """

    sent = "sent"
    failed = "failed"
    logged_only = "logged_only"


class NotificationDispatch(CosmosDocument):
    """Append-only log of every dispatched (or attempted) push.

    Partition key: ``user_id``. Stored in the per-tenant database,
    ``notification_dispatches`` collection.

    ``installation_id`` is null when the dispatch targeted a *tag*
    (e.g. "every Android device in workspace X") rather than a single
    install.
    """

    tenant_id: str
    user_id: str
    installation_id: str | None
    notification_type: NotificationType
    title: str
    body: str
    outcome: DispatchOutcome
    failure_reason: str | None = None
    dispatched_at: str
