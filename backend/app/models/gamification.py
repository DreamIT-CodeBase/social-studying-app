"""Gamification state — denormalised for fast reads, updated async."""

from pydantic import Field

from app.models.base import CosmosDocument


class Badge(CosmosDocument.__base__):
    badge_id: str
    name: str
    description: str
    icon: str
    earned_at: str


class GamificationState(CosmosDocument):
    """One document per student.

    Partition key: student_id.
    Stored in the tenant's database, 'gamification' collection.
    """

    tenant_id: str
    workspace_id: str
    student_id: str
    xp_total: int = 0
    xp_this_week: int = 0
    level: int = 1
    streak_days: int = 0
    longest_streak_days: int = 0
    last_active_date: str | None = None   # ISO date "2026-04-30"
    badges: list[Badge] = Field(default_factory=list)
    questions_answered: int = 0
    questions_correct: int = 0
    leaderboard_rank: int | None = None
