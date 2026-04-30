"""Shared base model and helper utilities for all Cosmos DB documents."""

from datetime import UTC, datetime

from pydantic import BaseModel, ConfigDict, Field


def utc_now() -> str:
    """Return current UTC time as an ISO 8601 string."""
    return datetime.now(UTC).isoformat()


class CosmosDocument(BaseModel):
    """Base class for every document stored in Cosmos DB.

    Cosmos DB for MongoDB API stores `_id` as the document identifier.
    We keep our own typed `id` field and let `_id` be managed by the driver.
    """

    model_config = ConfigDict(populate_by_name=True)

    id: str = Field(alias="_id")
    created_at: str = Field(default_factory=utc_now)
    updated_at: str = Field(default_factory=utc_now)
    deleted_at: str | None = None

    @property
    def is_deleted(self) -> bool:
        return self.deleted_at is not None

    def soft_delete(self) -> None:
        self.deleted_at = utc_now()
        self.updated_at = utc_now()

    def touch(self) -> None:
        self.updated_at = utc_now()
