"""Unit tests for app.services.azure_openai.

The real Azure OpenAI client is mocked end-to-end so tests run offline.
We verify: client construction guards, request shape (JSON mode, temp, max
tokens), response parsing, and error mapping.
"""

from __future__ import annotations

import json
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.core.exceptions import ServiceUnavailableError
from app.services import azure_openai


def _fake_completion(content: str, *, prompt_tokens: int = 10, completion_tokens: int = 20):
    """Build a fake ChatCompletion with the canonical shape the SDK returns."""
    completion = MagicMock()
    completion.choices = [MagicMock()]
    completion.choices[0].message = MagicMock(content=content)
    completion.usage = MagicMock(
        prompt_tokens=prompt_tokens,
        completion_tokens=completion_tokens,
    )
    return completion


def _patched_openai(completion):
    """Mock _client() to yield an async client that returns ``completion``."""
    fake_client = MagicMock()
    fake_client.chat = MagicMock()
    fake_client.chat.completions = MagicMock()
    fake_client.chat.completions.create = AsyncMock(return_value=completion)
    fake_client.__aenter__ = AsyncMock(return_value=fake_client)
    fake_client.__aexit__ = AsyncMock(return_value=False)
    return patch.object(azure_openai, "_client", return_value=fake_client), fake_client


# ── chat_json: happy path ────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_chat_json_parses_dict_response():
    completion = _fake_completion('{"topics": ["A", "B"]}')
    patched, fake_client = _patched_openai(completion)
    with patched:
        result = await azure_openai.chat_json(
            system_prompt="be json",
            user_prompt="hi",
            max_output_tokens=500,
        )
    assert result == {"topics": ["A", "B"]}
    fake_client.chat.completions.create.assert_awaited_once()


@pytest.mark.asyncio
async def test_chat_json_uses_json_mode_and_temperature():
    completion = _fake_completion('{"ok": true}')
    patched, fake_client = _patched_openai(completion)
    with patched:
        await azure_openai.chat_json(
            system_prompt="be json",
            user_prompt="hi",
            max_output_tokens=100,
            temperature=0.5,
        )
    call_kwargs = fake_client.chat.completions.create.await_args.kwargs
    assert call_kwargs["response_format"] == {"type": "json_object"}
    assert call_kwargs["temperature"] == 0.5
    assert call_kwargs["max_tokens"] == 100


@pytest.mark.asyncio
async def test_chat_json_default_temperature_is_low():
    """0.2 default — extraction tasks need stable output across re-runs."""
    completion = _fake_completion('{"ok": true}')
    patched, fake_client = _patched_openai(completion)
    with patched:
        await azure_openai.chat_json(
            system_prompt="be json",
            user_prompt="hi",
            max_output_tokens=100,
        )
    assert fake_client.chat.completions.create.await_args.kwargs["temperature"] == 0.2


@pytest.mark.asyncio
async def test_chat_json_passes_system_and_user_messages():
    completion = _fake_completion('{"ok": true}')
    patched, fake_client = _patched_openai(completion)
    with patched:
        await azure_openai.chat_json(
            system_prompt="SYS",
            user_prompt="USR",
            max_output_tokens=100,
        )
    messages = fake_client.chat.completions.create.await_args.kwargs["messages"]
    assert messages[0] == {"role": "system", "content": "SYS"}
    assert messages[1] == {"role": "user", "content": "USR"}


@pytest.mark.asyncio
async def test_chat_json_deployment_override(monkeypatch):
    completion = _fake_completion('{"ok": true}')
    patched, fake_client = _patched_openai(completion)
    with patched:
        await azure_openai.chat_json(
            system_prompt="be json",
            user_prompt="hi",
            max_output_tokens=100,
            deployment="gpt-4o-mini",
        )
    assert fake_client.chat.completions.create.await_args.kwargs["model"] == "gpt-4o-mini"


@pytest.mark.asyncio
async def test_chat_json_uses_settings_deployment_when_not_overridden(monkeypatch):
    monkeypatch.setattr(azure_openai.settings, "azure_openai_deployment", "my-deployment")
    completion = _fake_completion('{"ok": true}')
    patched, fake_client = _patched_openai(completion)
    with patched:
        await azure_openai.chat_json(
            system_prompt="be json", user_prompt="hi", max_output_tokens=100
        )
    assert fake_client.chat.completions.create.await_args.kwargs["model"] == "my-deployment"


# ── chat_json: error paths ──────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_chat_json_invalid_json_raises_value_error():
    completion = _fake_completion("not json at all{")
    patched, _ = _patched_openai(completion)
    with patched:
        with pytest.raises(ValueError, match="invalid JSON"):
            await azure_openai.chat_json(
                system_prompt="be json", user_prompt="hi", max_output_tokens=100
            )


@pytest.mark.asyncio
async def test_chat_json_empty_response_raises_value_error():
    completion = _fake_completion("")
    patched, _ = _patched_openai(completion)
    with patched:
        with pytest.raises(ValueError):
            await azure_openai.chat_json(
                system_prompt="be json", user_prompt="hi", max_output_tokens=100
            )


@pytest.mark.asyncio
async def test_chat_json_transport_error_becomes_service_unavailable():
    fake_client = MagicMock()
    fake_client.chat = MagicMock()
    fake_client.chat.completions = MagicMock()
    fake_client.chat.completions.create = AsyncMock(side_effect=RuntimeError("503"))
    fake_client.__aenter__ = AsyncMock(return_value=fake_client)
    fake_client.__aexit__ = AsyncMock(return_value=False)

    with patch.object(azure_openai, "_client", return_value=fake_client):
        with pytest.raises(ServiceUnavailableError, match="Azure OpenAI request failed"):
            await azure_openai.chat_json(
                system_prompt="be json", user_prompt="hi", max_output_tokens=100
            )


@pytest.mark.asyncio
async def test_chat_json_missing_credentials_raises_service_unavailable(monkeypatch):
    monkeypatch.setattr(azure_openai.settings, "azure_openai_endpoint", "")
    monkeypatch.setattr(azure_openai.settings, "azure_openai_key", "")
    with pytest.raises(ServiceUnavailableError):
        await azure_openai.chat_json(
            system_prompt="be json", user_prompt="hi", max_output_tokens=100
        )


# ── chat_json: roundtrip with realistic topic payload ───────────────────────


@pytest.mark.asyncio
async def test_chat_json_roundtrips_complex_payload():
    payload = {
        "topics": [
            {"name": "Photosynthesis", "complexity_level": 2, "page_refs": [1, 4]},
            {"name": "Cellular Respiration", "complexity_level": 3, "page_refs": [5]},
        ]
    }
    completion = _fake_completion(json.dumps(payload))
    patched, _ = _patched_openai(completion)
    with patched:
        result = await azure_openai.chat_json(
            system_prompt="be json", user_prompt="hi", max_output_tokens=500
        )
    assert result == payload
