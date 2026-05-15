"""Azure OpenAI client wrapper — single source of truth for GPT-4o calls.

Used by:
- Sprint 2.5: topic extraction (this sprint)
- Sprint 2.6: taxonomy merge
- Sprint 2.7: dependency graph inference
- Sprint 3+: question / flashcard generation (via the MCP server)

Why a wrapper and not the raw SDK in each caller
------------------------------------------------
Three concerns that every call site needs to handle the same way:
1. Configuration — endpoint, key, deployment all read from settings ONCE here.
2. JSON-mode discipline — we ALWAYS ask for ``response_format=json_object`` on
   structured outputs and parse strictly. Callers don't get a chance to forget.
3. Logging — token counts and call durations land in one place so cost
   monitoring can hook a single seam.

We use the async client (``AsyncAzureOpenAI``) directly — no ``asyncio.to_thread``
wrapping, no fallback to sync. The OpenAI SDK supports async natively.
"""

from __future__ import annotations

import json
import logging
import time
from typing import Any

from openai import AsyncAzureOpenAI
from openai.types.chat import ChatCompletionMessageParam

from app.core.config import settings
from app.core.exceptions import ServiceUnavailableError

logger = logging.getLogger(__name__)

# Azure OpenAI requires a pinned API version. 2024-10-21 is the current GA
# release supporting gpt-4o with JSON-mode `response_format=json_object`.
_API_VERSION = "2024-10-21"


def _client() -> AsyncAzureOpenAI:
    """Build the async Azure OpenAI client from settings.

    Raises:
        ServiceUnavailableError: endpoint or key missing.
    """
    if not settings.azure_openai_endpoint or not settings.azure_openai_key:
        raise ServiceUnavailableError(
            "Azure OpenAI is not configured "
            "(set AZURE_OPENAI_ENDPOINT and AZURE_OPENAI_KEY)."
        )
    return AsyncAzureOpenAI(
        azure_endpoint=settings.azure_openai_endpoint,
        api_key=settings.azure_openai_key,
        api_version=_API_VERSION,
    )


async def chat_json(
    *,
    system_prompt: str,
    user_prompt: str,
    max_output_tokens: int,
    temperature: float = 0.2,
    deployment: str | None = None,
) -> dict[str, Any]:
    """Send a chat completion in JSON mode and return the parsed dict.

    Why temperature=0.2: extraction tasks (topics, taxonomy merges, validations)
    want stable, near-deterministic output. Higher temperatures yield different
    topic name spellings across re-runs which then break the Sprint 2.6 merge
    step's idempotency.

    Args:
        system_prompt: System role content. Must instruct the model to return
            JSON; we set ``response_format={"type": "json_object"}`` but the SDK
            errors if the system prompt doesn't mention JSON.
        user_prompt: User role content (already templated — no {{vars}}).
        max_output_tokens: Hard cap on response size. Caller picks based on
            expected schema; e.g. topic extraction allows ~4K tokens.
        temperature: 0.0–2.0. Defaults to 0.2 for extraction tasks.
        deployment: Override the deployment name. Defaults to settings value.

    Returns:
        The parsed JSON object as a dict.

    Raises:
        ServiceUnavailableError: model is not reachable / not configured.
        ValueError: response was not valid JSON (rare — JSON mode usually
            prevents this, but model can still return ``{}`` if the prompt is
            ambiguous).
    """
    deployment_name = deployment or settings.azure_openai_deployment
    messages: list[ChatCompletionMessageParam] = [
        {"role": "system", "content": system_prompt},
        {"role": "user", "content": user_prompt},
    ]

    start = time.perf_counter()
    async with _client() as client:
        try:
            response = await client.chat.completions.create(
                model=deployment_name,
                messages=messages,
                response_format={"type": "json_object"},
                temperature=temperature,
                max_tokens=max_output_tokens,
            )
        except Exception as exc:
            logger.exception("Azure OpenAI chat completion failed")
            raise ServiceUnavailableError(
                f"Azure OpenAI request failed: {exc}"
            ) from exc

    duration_ms = int((time.perf_counter() - start) * 1000)
    usage = response.usage
    if usage:
        logger.info(
            "OpenAI chat.json deployment=%s prompt_tokens=%d completion_tokens=%d duration_ms=%d",
            deployment_name,
            usage.prompt_tokens,
            usage.completion_tokens,
            duration_ms,
        )

    content = response.choices[0].message.content or ""
    try:
        return json.loads(content)
    except json.JSONDecodeError as exc:
        # JSON mode usually prevents this, but a stub or empty response can
        # still parse-fail. Surface as ValueError so callers distinguish from
        # transport failures (ServiceUnavailableError).
        logger.error("OpenAI returned non-JSON despite JSON mode: %r", content)
        raise ValueError(f"OpenAI returned invalid JSON: {exc}") from exc


async def embed_texts(
    *,
    texts: list[str],
    deployment: str | None = None,
    batch_size: int | None = None,
) -> list[list[float]]:
    """Return one embedding vector per input text.

    Sprint 2.9 vectorization. Input ordering is preserved across batches —
    callers can zip ``texts`` with the returned vectors directly.

    Why batched
    -----------
    Azure OpenAI's embedding endpoint caps inputs per call (16 by default for
    text-embedding-3 deployments). Larger batches get a 400. We chunk inputs
    here so callers don't have to think about it; each batch is one API call
    with shared connection / TLS handshake overhead.

    Empty list short-circuits without an API call (matches the upstream
    contract — no work, no spend).

    Args:
        texts: Strings to embed. Empty strings are passed through to the API
            (which returns a zero-ish vector); callers that want to skip them
            should filter before calling.
        deployment: Override the embedding deployment name. Defaults to
            ``settings.azure_openai_embedding_deployment``.
        batch_size: Override the inputs-per-call cap. Defaults to
            ``settings.azure_openai_embedding_batch_size`` (16).

    Returns:
        Vectors in the same order as ``texts``. Each vector has length
        ``settings.azure_openai_embedding_dim`` (1536 for the small model).

    Raises:
        ServiceUnavailableError: model not reachable / not configured /
            transport failure mid-batch. The whole call fails — partial
            vectors aren't returned because the caller would have no way to
            know which texts succeeded.
    """
    chunk_size = (
        batch_size
        if batch_size is not None
        else settings.azure_openai_embedding_batch_size
    )
    if chunk_size < 1:
        raise ValueError(f"batch_size must be >= 1, got {chunk_size}")

    if not texts:
        return []

    deployment_name = deployment or settings.azure_openai_embedding_deployment

    out: list[list[float]] = []
    start = time.perf_counter()
    total_prompt_tokens = 0

    async with _client() as client:
        for offset in range(0, len(texts), chunk_size):
            batch = texts[offset : offset + chunk_size]
            try:
                response = await client.embeddings.create(
                    model=deployment_name,
                    input=batch,
                )
            except Exception as exc:
                logger.exception(
                    "Azure OpenAI embeddings call failed at offset=%d batch_size=%d",
                    offset,
                    len(batch),
                )
                raise ServiceUnavailableError(
                    f"Azure OpenAI embeddings request failed: {exc}"
                ) from exc

            # The SDK returns Embedding objects in input order. Pull them in
            # that order to preserve the text<->vector mapping the caller
            # relies on.
            for item in response.data:
                out.append(list(item.embedding))

            if response.usage:
                total_prompt_tokens += response.usage.prompt_tokens

    duration_ms = int((time.perf_counter() - start) * 1000)
    logger.info(
        "OpenAI embeddings deployment=%s inputs=%d batches=%d prompt_tokens=%d duration_ms=%d",
        deployment_name,
        len(texts),
        (len(texts) + chunk_size - 1) // chunk_size,
        total_prompt_tokens,
        duration_ms,
    )

    if len(out) != len(texts):
        # The API contract is one vector per input; anything else means the
        # SDK or service returned a malformed batch and we'd silently misalign
        # vectors with their source texts. Refuse to return.
        raise ServiceUnavailableError(
            f"Embeddings response shape mismatch: requested {len(texts)} got {len(out)}"
        )

    return out
