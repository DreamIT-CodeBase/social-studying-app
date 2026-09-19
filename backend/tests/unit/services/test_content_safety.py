"""Unit tests for app.services.content_safety.

Mock the Azure SDK client; we test our wrapper's logic (chunking, threshold
application, empty-text short-circuit, category aggregation).
"""

from __future__ import annotations

from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from azure.ai.contentsafety.models import TextCategory
from azure.core.exceptions import HttpResponseError

from app.services import content_safety

# ── Helpers ──────────────────────────────────────────────────────────────────


def _analysis(category: TextCategory, severity: int) -> MagicMock:
    """Build a fake TextCategoriesAnalysis row."""
    a = MagicMock()
    a.category = category
    a.severity = severity
    return a


def _result(severities: dict[TextCategory, int]) -> MagicMock:
    """Build a fake AnalyzeTextResult with the given per-category severities."""
    r = MagicMock()
    r.categories_analysis = [_analysis(cat, sev) for cat, sev in severities.items()]
    return r


def _patched_client(*chunk_results: MagicMock) -> object:
    """Return a context manager mocking _client() to yield an async client.

    Each successive call to client.analyze_text() returns the next chunk_result.
    """
    fake_client = MagicMock()
    fake_client.analyze_text = AsyncMock(side_effect=list(chunk_results))
    fake_client.__aenter__ = AsyncMock(return_value=fake_client)
    fake_client.__aexit__ = AsyncMock(return_value=False)
    return patch.object(content_safety, "_client", return_value=fake_client)


# ── Empty / whitespace short-circuit ─────────────────────────────────────────


@pytest.mark.asyncio
async def test_empty_text_returns_clean_verdict_without_api_call():
    with _patched_client() as patched:
        verdict = await content_safety.analyze_extracted_text("")
    assert verdict.flagged is False
    assert verdict.severities == {"Hate": 0, "SelfHarm": 0, "Sexual": 0, "Violence": 0}
    assert verdict.max_severity_normalized == 0.0
    # _client() must NOT have been entered — empty text never hits Azure.
    patched.assert_not_called()


@pytest.mark.asyncio
async def test_whitespace_only_text_short_circuits():
    with _patched_client() as patched:
        verdict = await content_safety.analyze_extracted_text("   \n\t  ")
    assert verdict.flagged is False
    patched.assert_not_called()


# ── Single-chunk clean ───────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_single_chunk_clean_text_returns_unflagged():
    result = _result(
        {
            TextCategory.HATE: 0,
            TextCategory.SELF_HARM: 0,
            TextCategory.SEXUAL: 0,
            TextCategory.VIOLENCE: 0,
        }
    )
    with _patched_client(result):
        verdict = await content_safety.analyze_extracted_text("photosynthesis is a process")
    assert verdict.flagged is False
    assert verdict.flagged_categories == []
    assert verdict.severities[TextCategory.HATE.value] == 0


# ── Threshold application: hate at 2 trips, violence at 2 doesn't ────────────


@pytest.mark.asyncio
async def test_hate_at_threshold_flags():
    """Default hate threshold is 2 — severity 2 must flag."""
    result = _result(
        {
            TextCategory.HATE: 2,
            TextCategory.SELF_HARM: 0,
            TextCategory.SEXUAL: 0,
            TextCategory.VIOLENCE: 0,
        }
    )
    with _patched_client(result):
        verdict = await content_safety.analyze_extracted_text("some text")
    assert verdict.flagged is True
    assert verdict.flagged_categories == ["Hate"]


@pytest.mark.asyncio
async def test_violence_below_lenient_threshold_does_not_flag():
    """Default violence threshold is 4 — severity 2 (mild) must NOT flag.

    This is the "history docs about war" guardrail from knowledge.md §10.
    """
    result = _result(
        {
            TextCategory.HATE: 0,
            TextCategory.SELF_HARM: 0,
            TextCategory.SEXUAL: 0,
            TextCategory.VIOLENCE: 2,
        }
    )
    with _patched_client(result):
        verdict = await content_safety.analyze_extracted_text("the battle of hastings ...")
    assert verdict.flagged is False
    assert verdict.severities[TextCategory.VIOLENCE.value] == 2


@pytest.mark.asyncio
async def test_violence_at_lenient_threshold_flags():
    """Default violence threshold is 4 — severity 4 trips."""
    result = _result(
        {
            TextCategory.HATE: 0,
            TextCategory.SELF_HARM: 0,
            TextCategory.SEXUAL: 0,
            TextCategory.VIOLENCE: 4,
        }
    )
    with _patched_client(result):
        verdict = await content_safety.analyze_extracted_text("gratuitously graphic content")
    assert verdict.flagged is True
    assert verdict.flagged_categories == ["Violence"]


# ── Multiple categories flag ─────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_multiple_flagged_categories_preserve_canonical_order():
    """Order must be Hate, SelfHarm, Sexual, Violence regardless of severity."""
    result = _result(
        {
            TextCategory.VIOLENCE: 6,
            TextCategory.HATE: 4,
            TextCategory.SEXUAL: 2,
            TextCategory.SELF_HARM: 0,
        }
    )
    with _patched_client(result):
        verdict = await content_safety.analyze_extracted_text("...")
    assert verdict.flagged_categories == ["Hate", "Sexual", "Violence"]


# ── Chunking: aggregate max severity across windows ──────────────────────────


@pytest.mark.asyncio
async def test_chunks_long_text_and_aggregates_max_severity():
    """A 12K-char document splits into two chunks; max severity wins."""
    # Chunk 1: clean. Chunk 2: hate=4. Final verdict: hate=4 (flagged).
    chunk_one = _result(
        {
            TextCategory.HATE: 0,
            TextCategory.SELF_HARM: 0,
            TextCategory.SEXUAL: 0,
            TextCategory.VIOLENCE: 0,
        }
    )
    chunk_two = _result(
        {
            TextCategory.HATE: 4,
            TextCategory.SELF_HARM: 0,
            TextCategory.SEXUAL: 0,
            TextCategory.VIOLENCE: 0,
        }
    )
    long_text = "a" * 12_000  # > _CHUNK_SIZE (9500) → 2 chunks
    fake_client = MagicMock()
    fake_client.analyze_text = AsyncMock(side_effect=[chunk_one, chunk_two])
    fake_client.__aenter__ = AsyncMock(return_value=fake_client)
    fake_client.__aexit__ = AsyncMock(return_value=False)

    with patch.object(content_safety, "_client", return_value=fake_client):
        verdict = await content_safety.analyze_extracted_text(long_text)

    assert fake_client.analyze_text.await_count == 2
    assert verdict.flagged is True
    assert verdict.severities["Hate"] == 4


# ── HTTP failure propagates ──────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_http_error_propagates_so_worker_can_retry():
    """Transient Content Safety failures must NOT be swallowed."""
    fake_client = MagicMock()
    fake_client.analyze_text = AsyncMock(side_effect=HttpResponseError(message="503"))
    fake_client.__aenter__ = AsyncMock(return_value=fake_client)
    fake_client.__aexit__ = AsyncMock(return_value=False)

    with (
        patch.object(content_safety, "_client", return_value=fake_client),
        pytest.raises(HttpResponseError),
    ):
        await content_safety.analyze_extracted_text("some content")


# ── Severities normalized to 0-1 ─────────────────────────────────────────────


@pytest.mark.asyncio
async def test_max_severity_normalized():
    """Max severity 6 → 1.0, severity 4 → ~0.667, severity 0 → 0.0."""
    result = _result(
        {
            TextCategory.HATE: 4,
            TextCategory.SELF_HARM: 0,
            TextCategory.SEXUAL: 0,
            TextCategory.VIOLENCE: 6,
        }
    )
    with _patched_client(result):
        verdict = await content_safety.analyze_extracted_text("...")
    assert verdict.max_severity_normalized == pytest.approx(1.0)  # max=6/6


# ── Threshold override via settings ──────────────────────────────────────────


@pytest.mark.asyncio
async def test_thresholds_respect_settings(monkeypatch):
    """Bumping the hate threshold from 2 to 6 should let severity 4 pass."""
    monkeypatch.setattr(content_safety.settings, "content_safety_hate_threshold", 6)
    result = _result(
        {
            TextCategory.HATE: 4,
            TextCategory.SELF_HARM: 0,
            TextCategory.SEXUAL: 0,
            TextCategory.VIOLENCE: 0,
        }
    )
    with _patched_client(result):
        verdict = await content_safety.analyze_extracted_text("...")
    assert verdict.flagged is False
    assert verdict.severities["Hate"] == 4


# ── Service unavailable when not configured ──────────────────────────────────


@pytest.mark.asyncio
async def test_missing_credentials_raises_service_unavailable(monkeypatch):
    from app.core.exceptions import ServiceUnavailableError

    monkeypatch.setattr(content_safety.settings, "content_safety_endpoint", "")
    monkeypatch.setattr(content_safety.settings, "content_safety_key", "")

    with pytest.raises(ServiceUnavailableError):
        await content_safety.analyze_extracted_text("anything non-empty")
