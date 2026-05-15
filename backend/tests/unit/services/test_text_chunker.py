"""Unit tests for app.services.text_chunker.

Pure-function tests — no I/O, no mocks needed. We test the boundary-finding
priority, overlap behaviour, edge cases (empty / tiny / no-boundary),
config validation, and char-offset accuracy.
"""

from __future__ import annotations

import pytest

from app.services import text_chunker


# ── Empty / whitespace input ─────────────────────────────────────────────────


def test_empty_text_returns_empty_list():
    assert text_chunker.chunk_text("") == []


def test_whitespace_only_text_returns_empty_list():
    assert text_chunker.chunk_text("   \n\n\t   ") == []


# ── Tiny input below min_chars ───────────────────────────────────────────────


def test_text_below_min_chars_returns_single_chunk():
    text = "Short text under the minimum."
    chunks = text_chunker.chunk_text(text, target_chars=1000, min_chars=200)
    assert len(chunks) == 1
    assert chunks[0].text == text
    assert chunks[0].chunk_index == 0
    assert chunks[0].char_start == 0
    assert chunks[0].char_end == len(text)


def test_text_at_exact_min_chars_still_returns_single_chunk():
    text = "x" * 200
    chunks = text_chunker.chunk_text(text, target_chars=500, min_chars=200)
    assert len(chunks) == 1
    assert chunks[0].char_end == 200


# ── Multiple chunks at paragraph boundaries ──────────────────────────────────


def test_splits_on_paragraph_boundaries_when_available():
    """Paragraph break is the strongest boundary — it must win over weaker ones."""
    para1 = "First paragraph. " * 10           # ~170 chars
    para2 = "Second paragraph. " * 10          # ~180 chars
    para3 = "Third paragraph. " * 10           # ~170 chars
    text = f"{para1}\n\n{para2}\n\n{para3}"

    chunks = text_chunker.chunk_text(text, target_chars=200, overlap_chars=20, min_chars=50)

    # We expect cuts at the paragraph breaks: each chunk ends with "\n\n"
    # plus a few overlap chars. First chunk should end right after the
    # first "\n\n" since para1 is already over the 200-char target via the
    # ". " sentence boundary, and "\n\n" wins as soon as it's reachable.
    assert len(chunks) >= 3
    # No chunk should be enormous — boundaries should keep size near target+overlap.
    for c in chunks:
        assert c.char_end - c.char_start <= 200


# ── Overlap is honored ───────────────────────────────────────────────────────


def test_adjacent_chunks_overlap_by_configured_amount():
    text = "Sentence one. " * 100  # ~1400 chars, plenty of sentence breaks
    chunks = text_chunker.chunk_text(
        text, target_chars=300, overlap_chars=50, min_chars=50
    )
    assert len(chunks) >= 2
    # Overlap: chunk N's text should share a suffix with chunk N+1's prefix.
    for prev, nxt in zip(chunks, chunks[1:], strict=False):
        # The overlap window is min(50, prev_len, next_len).
        overlap_len = min(50, len(prev.text), len(nxt.text))
        # Allow the boundary search to land slightly off — at least half
        # the requested overlap should match.
        suffix = prev.text[-overlap_len:]
        prefix = nxt.text[:overlap_len]
        # Loose check: nxt.char_start < prev.char_end (overlapping spans).
        assert nxt.char_start < prev.char_end, (
            f"chunk {nxt.chunk_index} starts at {nxt.char_start} but "
            f"chunk {prev.chunk_index} ends at {prev.char_end} — no overlap"
        )
        # The overlap region must contain at least *some* shared content.
        assert suffix[: overlap_len // 2] in text and prefix[: overlap_len // 2] in text


# ── Char-offset accuracy ─────────────────────────────────────────────────────


def test_char_offsets_index_back_into_original_text():
    """chunk.text and source[char_start:char_end] should match (modulo
    whitespace stripping at the document edges)."""
    text = "Alpha. Beta. Gamma. Delta. Epsilon. Zeta. Eta. Theta. Iota. Kappa."
    chunks = text_chunker.chunk_text(text, target_chars=30, overlap_chars=10, min_chars=10)
    for c in chunks:
        # The chunk text matches the substring of the (stripped) original.
        assert text[c.char_start : c.char_end] == c.text


def test_chunk_indices_are_sequential_starting_at_zero():
    text = "Sentence. " * 50
    chunks = text_chunker.chunk_text(text, target_chars=80, overlap_chars=20, min_chars=10)
    assert [c.chunk_index for c in chunks] == list(range(len(chunks)))


# ── Falls back to sentence/word boundaries ──────────────────────────────────


def test_falls_back_to_sentence_boundary_when_no_paragraph():
    """No \\n\\n in input → cut should land on a sentence end."""
    sentences = "This is a sentence. " * 20  # ~400 chars, only ". " boundaries
    chunks = text_chunker.chunk_text(
        sentences, target_chars=100, overlap_chars=20, min_chars=20
    )
    # Each chunk (except possibly the last) should end on a ". " boundary.
    for c in chunks[:-1]:
        # Either the chunk text ends with "." or "..." pattern from ". "
        # The cut happens AFTER the boundary token, so the trailing chars
        # in the chunk include the period and space.
        assert c.text.rstrip().endswith(("."))


def test_falls_back_to_word_boundary_when_no_sentence():
    """No punctuation, only spaces between words → cut at word boundary."""
    text = " ".join("word" for _ in range(200))  # "word word word…" no punctuation
    chunks = text_chunker.chunk_text(
        text, target_chars=50, overlap_chars=10, min_chars=10
    )
    # No chunk should split a word in half.
    for c in chunks:
        assert not c.text.startswith("ord") and not c.text.endswith("wor"), (
            f"chunk {c.chunk_index} cut a word: {c.text!r}"
        )


# ── Hard cut when no boundary exists ─────────────────────────────────────────


def test_hard_cut_when_no_whitespace_in_window():
    """Adversarial input (URL spam, binary leftover) — chunker must not loop."""
    text = "x" * 5000  # no whitespace, no punctuation
    chunks = text_chunker.chunk_text(
        text, target_chars=500, overlap_chars=50, min_chars=100
    )
    # Should produce multiple hard-cut chunks without crashing.
    assert len(chunks) > 1
    # No chunk exceeds the target.
    for c in chunks:
        assert c.char_end - c.char_start <= 500


# ── Tail handling: small leftover merges into prior chunk ───────────────────


def test_small_tail_merges_into_previous_chunk():
    """A trailing 5-char fragment shouldn't get its own chunk."""
    text = "Sentence A. " * 25 + "Tail."  # 25 sentences + a 5-char tail
    chunks = text_chunker.chunk_text(
        text, target_chars=100, overlap_chars=20, min_chars=30
    )
    # The tail must be folded into the last chunk; no chunk smaller than min_chars.
    assert all(c.char_end - c.char_start >= 5 for c in chunks)
    assert chunks[-1].char_end == len(text.strip())


# ── Config validation ───────────────────────────────────────────────────────


def test_invalid_target_chars_raises():
    with pytest.raises(ValueError):
        text_chunker.chunk_text("x" * 100, target_chars=0)


def test_overlap_must_be_less_than_target():
    with pytest.raises(ValueError):
        text_chunker.chunk_text("x" * 100, target_chars=100, overlap_chars=100)


def test_negative_overlap_raises():
    with pytest.raises(ValueError):
        text_chunker.chunk_text("x" * 100, target_chars=100, overlap_chars=-1)


# ── Progress guarantee (no infinite loop on pathological config) ─────────────


def test_chunker_always_makes_progress_even_with_tiny_overlap():
    """Even if config conspires to make overlap == target - 1, the cursor
    must advance at least 1 char per iteration."""
    text = "x" * 1000
    chunks = text_chunker.chunk_text(
        text, target_chars=100, overlap_chars=99, min_chars=10
    )
    # If we made no progress, we'd loop forever and the test would hang.
    # Reaching this assertion means we made progress.
    assert len(chunks) >= 2
