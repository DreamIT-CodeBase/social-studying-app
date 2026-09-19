from unittest.mock import MagicMock, patch

import pytest

from app.services.study_sources import current_study_sources


class _Cursor:
    def __init__(self, rows: list[dict]) -> None:
        self.rows = rows

    async def to_list(self, *, length: int) -> list[dict]:
        return self.rows[:length]


@pytest.mark.asyncio
async def test_current_sources_keep_latest_ready_version_per_filename():
    collection = MagicMock()
    collection.find.return_value = _Cursor(
        [
            {
                "_id": "doc_old_scrape",
                "filename": "scraped_example.txt",
                "created_at": "2026-07-16T10:00:00Z",
                "topic_tags": [{"name": "Old topic"}],
            },
            {
                "_id": "doc_pdf",
                "filename": "biology.pdf",
                "created_at": "2026-07-17T09:00:00Z",
                "topic_tags": [{"name": "Cells"}],
            },
            {
                "_id": "doc_new_scrape",
                "filename": "scraped_example.txt",
                "created_at": "2026-07-17T10:00:00Z",
                "topic_tags": [{"name": "Microbiology"}, {"name": "Cells"}],
            },
        ]
    )

    with patch("app.services.study_sources.get_collection", return_value=collection):
        sources = await current_study_sources(tenant_id="ten_a", workspace_id="wsp_a")

    assert sources.document_ids == frozenset({"doc_new_scrape", "doc_pdf"})
    assert sources.topic_names == ("Microbiology", "Cells")
    collection.find.assert_called_once_with(
        {
            "workspace_id": "wsp_a",
            "status": {"$in": ["ready", "vectorizing", "chunked", "topics_extracted"]},
            "deleted_at": None,
        }
    )
