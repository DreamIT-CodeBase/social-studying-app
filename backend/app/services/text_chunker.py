"""Text chunker — recursive character splitting with overlap.

Sprint 2.8. Pure function over a string; no AI, no I/O. Cuts a document's
extracted text into ~``settings.chunk_target_chars`` windows with
``settings.chunk_overlap_chars`` of overlap between adjacent chunks.

Splitting strategy
------------------
Recursive priority order: paragraph break → newline → sentence terminator
→ word boundary → hard cut. We walk the cut candidates from highest to
lowest priority and pick the latest cut that's within the chunk size
budget. This keeps semantic units intact when possible without padding
chunks past the target on long unbroken runs.

Why character-based instead of token-based
------------------------------------------
GPT-4o tokens average ~4 chars for English educational content. A 2K-char
chunk is roughly 500 tokens — well below any embedding model's input
limit and small enough that an LLM grounding on it doesn't get distracted.
Token-exact precision would require pulling in `tiktoken` as a new
dependency for a deterministic stage that doesn't otherwise touch any
OpenAI surface. Search before building, Layer 1 says no.

If/when 2.9 vectorization needs tighter token bounds (text-embedding-3 has
an 8191-token cap), we can add a tokenizer pass at THAT seam without
disturbing this one.

Why overlap
-----------
Without overlap, a paragraph straddling two chunks loses cross-reference
context: "Photosynthesis is..." in chunk N ends mid-sentence, "...the
process by which plants..." starts chunk N+1. Sprint 3's retrieval might
pick only one chunk, missing the full definition. 200 chars (~50 tokens)
of overlap is enough to keep one or two sentences in both neighbours.

Edge cases
----------
- Input below ``chunk_min_chars``: return a single chunk (no point
  splitting an already-tiny doc).
- Empty / whitespace-only input: return empty list.
- A run with NO whitespace > target_chars: hard-cut at exactly
  ``target_chars`` (last resort). We log this — usually means a binary
  blob slipped through Document Intelligence, worth investigating.
"""

from __future__ import annotations

import logging
from dataclasses import dataclass

from app.core.config import settings

logger = logging.getLogger(__name__)

# Cut-point candidate sequences in descending priority. We try each in
# order; the first that yields a clean boundary within the chunk budget
# wins. "Hard cut" at the bottom is the fallback for binary-ish runs.
_BOUNDARY_PATTERNS: tuple[str, ...] = (
    "\n\n",  # paragraph break — strongest semantic boundary
    "\n",  # newline
    ". ",  # sentence end (period followed by space — avoids "U.S.")
    "? ",
    "! ",
    "; ",  # clause boundary
    ", ",  # weak — only if everything else missed
    " ",  # word boundary — last resort before hard cut
)


@dataclass(frozen=True, slots=True)
class TextChunk:
    """Output of one chunk produced by :func:`chunk_text`.

    char_start/end are inclusive/exclusive indices into the ORIGINAL text
    (the un-overlapped boundaries). Useful for highlighting in Sprint 4's
    moderation UI and for re-chunking detection.
    """

    text: str
    chunk_index: int
    char_start: int
    char_end: int


def chunk_text(
    text: str,
    *,
    target_chars: int | None = None,
    overlap_chars: int | None = None,
    min_chars: int | None = None,
) -> list[TextChunk]:
    """Split ``text`` into overlapping chunks at the best available boundary.

    Default sizing comes from settings — keeping the tunables on the
    function signature too lets tests parameterize without monkeypatching.

    Returns chunks in document order. Chunks include the overlap region
    in their ``text`` (so retrieval gets the full context), but the
    ``char_start/end`` describe the un-overlapped span so callers can
    de-dup by position if needed.
    """
    target = target_chars if target_chars is not None else settings.chunk_target_chars
    overlap = overlap_chars if overlap_chars is not None else settings.chunk_overlap_chars
    min_size = min_chars if min_chars is not None else settings.chunk_min_chars

    if target <= 0:
        raise ValueError(f"target_chars must be positive, got {target}")
    if overlap < 0 or overlap >= target:
        raise ValueError(
            f"overlap_chars must be in [0, target_chars); got overlap={overlap} target={target}"
        )

    stripped = text.strip()
    if not stripped:
        return []
    if len(stripped) <= min_size:
        # Too small to bother splitting — one chunk holds the whole thing.
        return [TextChunk(text=stripped, chunk_index=0, char_start=0, char_end=len(stripped))]

    chunks: list[TextChunk] = []
    cursor = 0
    text_len = len(stripped)

    while cursor < text_len:
        # Build the candidate window. Don't run past the end.
        window_end_max = min(cursor + target, text_len)

        if window_end_max == text_len:
            # Final window — take everything that's left, no boundary search
            # needed (we can't run off the end). Honor min_chars by absorbing
            # a too-tiny tail into the previous chunk instead of emitting it
            # as its own chunk.
            tail = stripped[cursor:text_len]
            if chunks and len(tail.strip()) < min_size:
                last = chunks[-1]
                merged_text = stripped[last.char_start : text_len]
                chunks[-1] = TextChunk(
                    text=merged_text,
                    chunk_index=last.chunk_index,
                    char_start=last.char_start,
                    char_end=text_len,
                )
            else:
                chunks.append(
                    TextChunk(
                        text=tail,
                        chunk_index=len(chunks),
                        char_start=cursor,
                        char_end=text_len,
                    )
                )
            break

        cut = _find_cut(stripped, cursor, window_end_max)
        # If no boundary found in the window, hard-cut at the budget edge.
        # This happens for adversarial inputs (URL spam, binary leftovers).
        if cut is None or cut <= cursor:
            logger.warning(
                "No boundary in window [%d, %d) — hard-cutting at %d",
                cursor,
                window_end_max,
                window_end_max,
            )
            cut = window_end_max

        chunk_text_str = stripped[cursor:cut]
        chunks.append(
            TextChunk(
                text=chunk_text_str,
                chunk_index=len(chunks),
                char_start=cursor,
                char_end=cut,
            )
        )

        # Advance cursor with overlap. Bound by `cut - 1` so we always
        # make at least one char of progress — protects against weird
        # configs where overlap >= target.
        next_cursor = max(cursor + 1, cut - overlap)
        cursor = next_cursor

    return chunks


# ── Boundary search ──────────────────────────────────────────────────────────


def _find_cut(text: str, start: int, end: int) -> int | None:
    """Return the highest-priority boundary index in ``text[start:end]``.

    Walks the boundary pattern list in priority order. For each pattern,
    finds the LATEST occurrence in the window (rightmost — to maximise
    chunk size while respecting the boundary). Returns the index just
    after the boundary (so the cut leaves the boundary token at the end
    of the prior chunk for sentence-end patterns).

    Returns ``None`` when no boundary exists in the window.
    """
    for pattern in _BOUNDARY_PATTERNS:
        idx = text.rfind(pattern, start, end)
        if idx == -1:
            continue
        # Cut AFTER the boundary so "Hello. " ends the prior chunk with
        # the trailing space; the next chunk starts on the first char of
        # the next sentence.
        return idx + len(pattern)
    return None
