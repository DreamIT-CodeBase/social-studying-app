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


# ── embed_texts: Sprint 2.9 ──────────────────────────────────────────────────


def _fake_embeddings(vectors: list[list[float]], *, prompt_tokens: int = 5):
    """Build a fake embeddings response with the SDK shape (data + usage)."""
    response = MagicMock()
    items = []
    for v in vectors:
        item = MagicMock()
        item.embedding = v
        items.append(item)
    response.data = items
    response.usage = MagicMock(prompt_tokens=prompt_tokens)
    return response


def _patched_embeddings(responses: list):
    """Mock _client() to return responses sequentially across batches."""
    fake_client = MagicMock()
    fake_client.embeddings = MagicMock()
    fake_client.embeddings.create = AsyncMock(side_effect=responses)
    fake_client.__aenter__ = AsyncMock(return_value=fake_client)
    fake_client.__aexit__ = AsyncMock(return_value=False)
    return patch.object(azure_openai, "_client", return_value=fake_client), fake_client


@pytest.mark.asyncio
async def test_embed_texts_single_batch_returns_vectors_in_order():
    vectors = [[0.1, 0.2], [0.3, 0.4], [0.5, 0.6]]
    patched, fake_client = _patched_embeddings([_fake_embeddings(vectors)])
    with patched:
        out = await azure_openai.embed_texts(
            texts=["a", "b", "c"], batch_size=16
        )
    assert out == vectors
    fake_client.embeddings.create.assert_awaited_once()
    call = fake_client.embeddings.create.await_args
    assert call.kwargs["input"] == ["a", "b", "c"]


@pytest.mark.asyncio
async def test_embed_texts_uses_settings_deployment_by_default(monkeypatch):
    monkeypatch.setattr(
        azure_openai.settings, "azure_openai_embedding_deployment", "embed-default"
    )
    patched, fake_client = _patched_embeddings([_fake_embeddings([[0.0]])])
    with patched:
        await azure_openai.embed_texts(texts=["x"])
    assert fake_client.embeddings.create.await_args.kwargs["model"] == "embed-default"


@pytest.mark.asyncio
async def test_embed_texts_deployment_override():
    patched, fake_client = _patched_embeddings([_fake_embeddings([[0.0]])])
    with patched:
        await azure_openai.embed_texts(texts=["x"], deployment="embed-override")
    assert fake_client.embeddings.create.await_args.kwargs["model"] == "embed-override"


@pytest.mark.asyncio
async def test_embed_texts_batches_and_preserves_input_order():
    """5 inputs with batch_size=2 → 3 API calls (2,2,1), output stays ordered."""
    responses = [
        _fake_embeddings([[1.0], [2.0]]),
        _fake_embeddings([[3.0], [4.0]]),
        _fake_embeddings([[5.0]]),
    ]
    patched, fake_client = _patched_embeddings(responses)
    with patched:
        out = await azure_openai.embed_texts(
            texts=["a", "b", "c", "d", "e"], batch_size=2
        )
    assert out == [[1.0], [2.0], [3.0], [4.0], [5.0]]
    assert fake_client.embeddings.create.await_count == 3
    sent_inputs = [
        c.kwargs["input"]
        for c in fake_client.embeddings.create.await_args_list
    ]
    assert sent_inputs == [["a", "b"], ["c", "d"], ["e"]]


@pytest.mark.asyncio
async def test_embed_texts_empty_input_short_circuits_no_api_call():
    """Empty input list returns [] without contacting the model."""
    fake_client = MagicMock()
    fake_client.embeddings = MagicMock()
    fake_client.embeddings.create = AsyncMock()
    fake_client.__aenter__ = AsyncMock(return_value=fake_client)
    fake_client.__aexit__ = AsyncMock(return_value=False)
    with patch.object(azure_openai, "_client", return_value=fake_client):
        out = await azure_openai.embed_texts(texts=[])
    assert out == []
    fake_client.embeddings.create.assert_not_awaited()


@pytest.mark.asyncio
async def test_embed_texts_transport_error_becomes_service_unavailable():
    fake_client = MagicMock()
    fake_client.embeddings = MagicMock()
    fake_client.embeddings.create = AsyncMock(side_effect=RuntimeError("503"))
    fake_client.__aenter__ = AsyncMock(return_value=fake_client)
    fake_client.__aexit__ = AsyncMock(return_value=False)
    with patch.object(azure_openai, "_client", return_value=fake_client):
        with pytest.raises(ServiceUnavailableError, match="embeddings request failed"):
            await azure_openai.embed_texts(texts=["x"])


@pytest.mark.asyncio
async def test_embed_texts_count_mismatch_raises_service_unavailable():
    """If the SDK returns fewer vectors than inputs, refuse to misalign."""
    # Asked for 2, response has 1 — would silently drop a chunk's embedding.
    patched, _ = _patched_embeddings([_fake_embeddings([[1.0]])])
    with patched:
        with pytest.raises(ServiceUnavailableError, match="shape mismatch"):
            await azure_openai.embed_texts(texts=["a", "b"], batch_size=16)


@pytest.mark.asyncio
async def test_embed_texts_invalid_batch_size_raises_value_error():
    with pytest.raises(ValueError):
        await azure_openai.embed_texts(texts=["x"], batch_size=0)


@pytest.mark.asyncio
async def test_embed_texts_missing_credentials_raises_service_unavailable(monkeypatch):
    monkeypatch.setattr(azure_openai.settings, "azure_openai_endpoint", "")
    monkeypatch.setattr(azure_openai.settings, "azure_openai_key", "")
    with pytest.raises(ServiceUnavailableError):
        await azure_openai.embed_texts(texts=["x"])
