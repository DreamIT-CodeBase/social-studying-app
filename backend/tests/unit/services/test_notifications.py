"""Unit tests for the notification service (Sprint 5.7).

Covers:

* Sender factory (LoggingSender vs AzureNotificationHubSender) based on
  settings.
* ``LoggingSender`` is a no-op that returns ``logged_only`` — the dev /
  no-creds default.
* Connection-string parsing + SAS minting (the parts of the ANH sender
  that don't touch the network).
* ``register_token`` is an upsert keyed by installation_id; re-registers
  preserve ``registered_at``.
* ``delete_token`` is idempotent.
* ``dispatch_to_user`` iterates over every active token and writes one
  dispatch row per attempt.
* Token-typed helpers (``send_milestone``, ``send_study_reminder``,
  ``send_streak_warning``) carry the right ``type`` data field for the
  Flutter tap handler to branch on.
"""

from __future__ import annotations

from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.models.notification import (
    DevicePlatform,
    DispatchOutcome,
    NotificationToken,
    NotificationType,
)
from app.services import notifications as notification_service
from app.services.notifications import (
    AzureNotificationHubSender,
    LoggingSender,
    NotificationPayload,
    _anh_format_for,
    _parse_connection_string,
    _platform_payload,
    delete_token,
    dispatch_to_user,
    get_sender,
    register_token,
    send_milestone,
    send_streak_warning,
    send_study_reminder,
    set_sender_for_tests,
)

# ── Sender factory ────────────────────────────────────────────────────────


def test_get_sender_returns_logging_sender_when_creds_missing():
    set_sender_for_tests(None)
    with (
        patch.object(notification_service.settings, "notification_hub_connection_string", ""),
        patch.object(notification_service.settings, "notification_hub_name", ""),
    ):
        sender = get_sender()
    assert isinstance(sender, LoggingSender)
    set_sender_for_tests(None)


def test_get_sender_returns_anh_sender_when_creds_present():
    set_sender_for_tests(None)
    with (
        patch.object(
            notification_service.settings,
            "notification_hub_connection_string",
            "Endpoint=sb://ns.servicebus.windows.net/;"
            "SharedAccessKeyName=key;SharedAccessKey=value",
        ),
        patch.object(notification_service.settings, "notification_hub_name", "study-app-dev"),
    ):
        sender = get_sender()
    assert isinstance(sender, AzureNotificationHubSender)
    set_sender_for_tests(None)


def test_set_sender_for_tests_overrides_factory():
    fake = LoggingSender()
    set_sender_for_tests(fake)
    assert get_sender() is fake
    set_sender_for_tests(None)


# ── LoggingSender ────────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_logging_sender_returns_logged_only():
    sender = LoggingSender()
    result = await sender.send_to_installation(
        installation_id="inst_a",
        device_token="tok_a",
        platform=DevicePlatform.android,
        payload=NotificationPayload(
            notification_type=NotificationType.milestone,
            title="hi",
            body="there",
        ),
    )
    assert result.outcome == DispatchOutcome.logged_only
    assert result.failure_reason is None


# ── Connection string + SAS helpers ──────────────────────────────────────


def test_parse_connection_string_normalises_endpoint_to_https():
    parsed = _parse_connection_string(
        "Endpoint=sb://ns.servicebus.windows.net/;"
        "SharedAccessKeyName=root;SharedAccessKey=secret123"
    )
    assert parsed["endpoint"] == "https://ns.servicebus.windows.net/"
    assert parsed["key_name"] == "root"
    assert parsed["key_value"] == "secret123"


def test_parse_connection_string_tolerates_missing_trailing_slash():
    parsed = _parse_connection_string(
        "Endpoint=sb://ns.servicebus.windows.net;SharedAccessKeyName=k;SharedAccessKey=v"
    )
    assert parsed["endpoint"].endswith("/")


def test_anh_format_for_uses_fcmv1_for_both_mobile_clients():
    # FCM v1 format header — exact casing matters (ANH rejects ``fcmv1``
    # / ``gcm``). Legacy ``gcm`` was retired 2024-06-20.
    assert _anh_format_for(DevicePlatform.android) == "fcmV1"
    assert _anh_format_for(DevicePlatform.ios) == "fcmV1"


def test_platform_payload_android_uses_fcmv1_message_envelope():
    payload = NotificationPayload(
        notification_type=NotificationType.milestone,
        title="hi",
        body="there",
        data={"workspace_id": "wsp_a"},
    )
    body = _platform_payload(platform=DevicePlatform.android, payload=payload)
    import json

    parsed = json.loads(body)
    # FCM v1 wraps everything under a top-level ``message`` object.
    assert parsed["message"]["notification"]["title"] == "hi"
    assert parsed["message"]["notification"]["body"] == "there"
    assert parsed["message"]["data"]["workspace_id"] == "wsp_a"
    # No legacy flat keys, no PNS target field (ANH injects via header).
    assert "notification" not in parsed
    assert "token" not in parsed["message"]
    assert "topic" not in parsed["message"]


def test_platform_payload_ios_uses_fcmv1_apns_envelope():
    payload = NotificationPayload(
        notification_type=NotificationType.milestone,
        title="hi",
        body="there",
        data={"badge_id": "first_steps"},
    )
    body = _platform_payload(platform=DevicePlatform.ios, payload=payload)
    import json

    parsed = json.loads(body)
    assert parsed["message"]["notification"]["title"] == "hi"
    assert parsed["message"]["data"]["badge_id"] == "first_steps"
    assert parsed["message"]["apns"]["headers"]["apns-priority"] == "10"
    assert parsed["message"]["apns"]["payload"]["aps"]["sound"] == "default"


# ── ANH sender (mocked transport) ────────────────────────────────────────


@pytest.mark.asyncio
async def test_anh_sender_returns_sent_on_2xx():
    response = MagicMock()
    response.status_code = 200
    response.text = ""
    client = MagicMock()
    client.post = AsyncMock(return_value=response)

    sender = AzureNotificationHubSender(
        connection_string=(
            "Endpoint=sb://ns.servicebus.windows.net/;"
            "SharedAccessKeyName=k;SharedAccessKey=dmFsdWU="  # "value" base64
        ),
        hub_name="study-app-dev",
        http_client=client,
    )
    result = await sender.send_to_installation(
        installation_id="inst_a",
        device_token="tok_a",
        platform=DevicePlatform.android,
        payload=NotificationPayload(
            notification_type=NotificationType.milestone,
            title="hi",
            body="there",
        ),
    )
    assert result.outcome == DispatchOutcome.sent
    # SAS header was included.
    _, kwargs = client.post.call_args
    assert kwargs["headers"]["Authorization"].startswith("SharedAccessSignature")
    # Device handle = device token.
    assert kwargs["headers"]["ServiceBusNotification-DeviceHandle"] == "tok_a"


@pytest.mark.asyncio
async def test_anh_sender_returns_failed_on_4xx_with_reason():
    response = MagicMock()
    response.status_code = 410
    response.text = "registration expired"
    client = MagicMock()
    client.post = AsyncMock(return_value=response)

    sender = AzureNotificationHubSender(
        connection_string=(
            "Endpoint=sb://ns.servicebus.windows.net/;"
            "SharedAccessKeyName=k;SharedAccessKey=dmFsdWU="
        ),
        hub_name="study-app-dev",
        http_client=client,
    )
    result = await sender.send_to_installation(
        installation_id="inst_dead",
        device_token="tok_dead",
        platform=DevicePlatform.android,
        payload=NotificationPayload(
            notification_type=NotificationType.milestone,
            title="hi",
            body="there",
        ),
    )
    assert result.outcome == DispatchOutcome.failed
    assert "410" in (result.failure_reason or "")


# ── Token CRUD ────────────────────────────────────────────────────────────


def _fake_token_collection(initial: dict | None = None):
    """Mutable in-memory token collection. Same pattern as
    test_knowledge_state.py — find_one returns the stored doc,
    replace_one overwrites it.
    """
    state: dict[str, dict | None] = {"current": initial}
    col = MagicMock()

    async def _find_one(_filter):
        return state["current"]

    async def _replace_one(_filter, doc, upsert=False):
        state["current"] = doc
        return MagicMock(matched_count=1, upserted_id=doc["_id"])

    async def _update_one(_filter, update):
        if state["current"] is None:
            return MagicMock(modified_count=0)
        # Apply $set fields.
        set_fields = update.get("$set", {})
        state["current"] = {**state["current"], **set_fields}
        return MagicMock(modified_count=1)

    col.find_one = _find_one
    col.replace_one = _replace_one
    col.update_one = _update_one
    return col, state


@pytest.mark.asyncio
async def test_register_token_writes_token_keyed_by_installation():
    col, store = _fake_token_collection(initial=None)
    with patch.object(notification_service, "get_collection", return_value=col):
        result = await register_token(
            tenant_id="ten_a",
            user_id="usr_a",
            installation_id="inst_xyz",
            token="fcm-token-12345",
            platform=DevicePlatform.android,
        )
    assert result.token == "fcm-token-12345"
    assert result.platform == DevicePlatform.android
    persisted = store["current"]
    assert persisted is not None
    assert persisted["user_id"] == "usr_a"
    assert persisted["installation_id"] == "inst_xyz"
    # Deterministic id keyed by installation — first 3 chars pin the prefix.
    assert persisted["_id"].startswith("ntk_")


@pytest.mark.asyncio
async def test_register_token_reregister_preserves_registered_at():
    initial = NotificationToken(
        **{"_id": "ntk_seed"},
        tenant_id="ten_a",
        user_id="usr_a",
        installation_id="inst_xyz",
        token="old-fcm-token",
        platform=DevicePlatform.android,
        registered_at="2026-05-20T10:00:00+00:00",
        last_seen_at="2026-05-20T10:00:00+00:00",
    ).model_dump(by_alias=True)
    col, store = _fake_token_collection(initial=initial)
    with patch.object(notification_service, "get_collection", return_value=col):
        result = await register_token(
            tenant_id="ten_a",
            user_id="usr_a",
            installation_id="inst_xyz",
            token="new-fcm-token",
            platform=DevicePlatform.android,
        )
    # The original registered_at survives the re-register.
    assert result.registered_at == "2026-05-20T10:00:00+00:00"
    # But last_seen_at bumps to now.
    assert result.last_seen_at != "2026-05-20T10:00:00+00:00"
    # Token rotates.
    assert result.token == "new-fcm-token"


@pytest.mark.asyncio
async def test_delete_token_returns_true_when_row_existed():
    initial = NotificationToken(
        **{"_id": "ntk_seed"},
        tenant_id="ten_a",
        user_id="usr_a",
        installation_id="inst_xyz",
        token="t",
        platform=DevicePlatform.android,
        registered_at="2026-05-20T10:00:00+00:00",
        last_seen_at="2026-05-20T10:00:00+00:00",
    ).model_dump(by_alias=True)
    col, _ = _fake_token_collection(initial=initial)
    with patch.object(notification_service, "get_collection", return_value=col):
        result = await delete_token(
            tenant_id="ten_a",
            user_id="usr_a",
            installation_id="inst_xyz",
        )
    assert result is True


@pytest.mark.asyncio
async def test_delete_token_returns_false_when_row_missing():
    col, _ = _fake_token_collection(initial=None)
    with patch.object(notification_service, "get_collection", return_value=col):
        result = await delete_token(
            tenant_id="ten_a",
            user_id="usr_a",
            installation_id="never_registered",
        )
    assert result is False


# ── dispatch_to_user ─────────────────────────────────────────────────────


def _async_iter(items):
    class _Iter:
        def __init__(self, xs):
            self._xs = iter(xs)

        def __aiter__(self):
            return self

        async def __anext__(self):
            try:
                return next(self._xs)
            except StopIteration as exc:
                raise StopAsyncIteration from exc

    return _Iter(items)


@pytest.mark.asyncio
async def test_dispatch_to_user_fans_out_to_every_active_token():
    tokens = [
        NotificationToken(
            **{"_id": f"ntk_{i}"},
            tenant_id="ten_a",
            user_id="usr_a",
            installation_id=f"inst_{i}",
            token=f"tok_{i}",
            platform=DevicePlatform.android,
            registered_at="2026-05-20T10:00:00+00:00",
            last_seen_at="2026-05-20T10:00:00+00:00",
        ).model_dump(by_alias=True)
        for i in range(3)
    ]
    tokens_col = MagicMock()
    tokens_col.find = MagicMock(return_value=_async_iter(tokens))
    dispatches_col = MagicMock()
    captured: list[dict] = []
    dispatches_col.insert_one = AsyncMock(
        side_effect=lambda d: captured.append(d) or MagicMock(inserted_id=d["_id"])
    )

    def _factory(_tid, collection):
        from app.core.database import NOTIFICATION_DISPATCHES, NOTIFICATION_TOKENS

        if collection == NOTIFICATION_TOKENS:
            return tokens_col
        if collection == NOTIFICATION_DISPATCHES:
            return dispatches_col
        raise AssertionError(collection)

    fake_sender = LoggingSender()
    set_sender_for_tests(fake_sender)
    try:
        with patch.object(notification_service, "get_collection", side_effect=_factory):
            results = await dispatch_to_user(
                tenant_id="ten_a",
                user_id="usr_a",
                payload=NotificationPayload(
                    notification_type=NotificationType.milestone,
                    title="hi",
                    body="there",
                ),
            )
    finally:
        set_sender_for_tests(None)

    assert len(results) == 3
    assert all(r.outcome == DispatchOutcome.logged_only for r in results)
    # One dispatch row per token attempted — including ``logged_only`` ones,
    # so we can prove the rule fired even without a live channel.
    assert len(captured) == 3
    assert all(row["outcome"] == DispatchOutcome.logged_only.value for row in captured)


@pytest.mark.asyncio
async def test_dispatch_to_user_no_tokens_returns_empty_list_without_writing():
    tokens_col = MagicMock()
    tokens_col.find = MagicMock(return_value=_async_iter([]))
    dispatches_col = MagicMock()
    dispatches_col.insert_one = AsyncMock()

    def _factory(_tid, collection):
        from app.core.database import NOTIFICATION_DISPATCHES, NOTIFICATION_TOKENS

        if collection == NOTIFICATION_TOKENS:
            return tokens_col
        if collection == NOTIFICATION_DISPATCHES:
            return dispatches_col
        raise AssertionError(collection)

    set_sender_for_tests(LoggingSender())
    try:
        with patch.object(notification_service, "get_collection", side_effect=_factory):
            results = await dispatch_to_user(
                tenant_id="ten_a",
                user_id="usr_a",
                payload=NotificationPayload(
                    notification_type=NotificationType.milestone,
                    title="hi",
                    body="there",
                ),
            )
    finally:
        set_sender_for_tests(None)

    assert results == []
    dispatches_col.insert_one.assert_not_awaited()


# ── Typed helpers ────────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_send_milestone_includes_badge_id_and_new_level_in_payload():
    """Captured via a fake dispatch_to_user — proves the wire shape."""
    captured: dict = {}

    async def _capture(*, tenant_id, user_id, payload):
        captured["payload"] = payload
        return []

    with patch.object(notification_service, "dispatch_to_user", _capture):
        await send_milestone(
            tenant_id="ten_a",
            user_id="usr_a",
            workspace_id="wsp_a",
            title="Level up!",
            body="You're now level 4.",
            badge_id="first_steps",
            new_level=4,
        )
    payload = captured["payload"]
    assert payload.notification_type == NotificationType.milestone
    assert payload.data == {
        "type": NotificationType.milestone.value,
        "workspace_id": "wsp_a",
        "badge_id": "first_steps",
        "new_level": "4",
    }


@pytest.mark.asyncio
async def test_send_study_reminder_pluralises_question_count():
    captured: dict = {}

    async def _capture(*, tenant_id, user_id, payload):
        captured["payload"] = payload
        return []

    with patch.object(notification_service, "dispatch_to_user", _capture):
        await send_study_reminder(
            tenant_id="ten_a",
            user_id="usr_a",
            workspace_id="wsp_a",
            questions_per_day=5,
        )
    assert "5 questions" in captured["payload"].body
    assert captured["payload"].data["type"] == "study_reminder"


@pytest.mark.asyncio
async def test_send_study_reminder_singular_one_question():
    captured: dict = {}

    async def _capture(*, tenant_id, user_id, payload):
        captured["payload"] = payload
        return []

    with patch.object(notification_service, "dispatch_to_user", _capture):
        await send_study_reminder(
            tenant_id="ten_a",
            user_id="usr_a",
            workspace_id="wsp_a",
            questions_per_day=1,
        )
    assert "one question" in captured["payload"].body.lower()


@pytest.mark.asyncio
async def test_send_streak_warning_includes_streak_in_data():
    captured: dict = {}

    async def _capture(*, tenant_id, user_id, payload):
        captured["payload"] = payload
        return []

    with patch.object(notification_service, "dispatch_to_user", _capture):
        await send_streak_warning(
            tenant_id="ten_a",
            user_id="usr_a",
            workspace_id="wsp_a",
            streak_days=12,
        )
    assert captured["payload"].data == {
        "type": NotificationType.streak_warning.value,
        "workspace_id": "wsp_a",
        "streak_days": "12",
    }
    assert "12-day streak" in captured["payload"].body
