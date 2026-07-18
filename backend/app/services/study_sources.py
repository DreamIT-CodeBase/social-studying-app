"""Resolve the current ready study-material snapshot for a workspace."""

from __future__ import annotations

from dataclasses import dataclass

from app.core.database import DOCUMENTS, get_collection


@dataclass(frozen=True, slots=True)
class CurrentStudySources:
    """Ready source documents and their topic names.

    Re-scraping the same URL produces the same generated filename. Only the
    newest ready record for that filename is current; older records remain in
    storage for audit but must not keep feeding newly generated study content.
    """

    document_ids: frozenset[str]
    topic_names: tuple[str, ...]


async def current_study_sources(*, tenant_id: str, workspace_id: str) -> CurrentStudySources:
    cursor = get_collection(tenant_id, DOCUMENTS).find(
        {
            "workspace_id": workspace_id,
            "status": "ready",
            "deleted_at": None,
        }
    )
    rows = await cursor.to_list(length=1000)
    rows.sort(key=lambda row: str(row.get("created_at", "")), reverse=True)

    selected: list[dict] = []
    seen_source_keys: set[str] = set()
    for row in rows:
        document_id = str(row.get("_id", ""))
        if not document_id:
            continue
        filename = " ".join(str(row.get("filename", "")).casefold().split())
        source_key = filename or document_id
        if source_key in seen_source_keys:
            continue
        seen_source_keys.add(source_key)
        selected.append(row)

    topic_names: list[str] = []
    seen_topics: set[str] = set()
    for row in selected:
        for tag in row.get("topic_tags") or []:
            name = str(tag.get("name", "")).strip() if isinstance(tag, dict) else ""
            key = name.casefold()
            if not name or key in seen_topics:
                continue
            seen_topics.add(key)
            topic_names.append(name)

    return CurrentStudySources(
        document_ids=frozenset(str(row["_id"]) for row in selected),
        topic_names=tuple(topic_names),
    )
