"""Gamification state — denormalised for fast reads, updated async."""

from pydantic import BaseModel, Field

from app.models.base import CosmosDocument


class Badge(BaseModel):
    """An earned badge — embedded inside :class:`GamificationState`.

    The engine writes one of these every time
    :func:`app.services.badges.evaluate_badges` returns a fresh unlock.
    ``icon`` is a Material Icons name (e.g. ``"local_fire_department"``)
    so the Flutter UI can render it via ``Icons``.
    """

    badge_id: str
    name: str
    description: str
    icon: str
    earned_at: str
    xp_reward: int = 0


class GamificationState(CosmosDocument):
    """One document per (student, workspace).

    Partition key: student_id.
    Stored in the tenant's database, ``gamification`` collection.

    The document is denormalised — every counter the leaderboard /
    profile / progress views read off this doc directly, no live
    aggregation over interactions. Sprint 5 engine (services/
    gamification.py) is the only writer.
    """

    tenant_id: str
    workspace_id: str
    student_id: str

    # XP counters
    xp_total: int = 0
    xp_this_week: int = 0
    xp_by_topic: dict[str, int] = Field(default_factory=dict)
    """Per-topic XP. Key is the topic display name (matching
    KnowledgeState.topics[i].topic). Powers the per-topic mastery + XP
    bars on the student progress view."""

    week_starts_at: str | None = None
    """ISO date (YYYY-MM-DD UTC) of the Monday that opens the current
    weekly XP window. When the engine sees an event past
    week_starts_at + 7d it resets ``xp_this_week`` and slides
    ``week_starts_at`` forward."""

    # Level
    level: int = 1

    # Streak
    streak_days: int = 0
    longest_streak_days: int = 0
    last_active_date: str | None = None  # ISO date "2026-04-30"

    # Badges
    badges: list[Badge] = Field(default_factory=list)

    # Activity counters
    questions_answered: int = 0
    questions_correct: int = 0
    flashcards_reviewed: int = 0
    flashcards_remembered: int = 0
    study_sessions_completed: int = 0
    revision_sessions_completed: int = 0
    flashcard_sessions_completed: int = 0
    perfect_sessions: int = 0
    last_login_reward_date: str | None = None

    daily_activity: dict[str, int] = Field(default_factory=dict)
    """date_iso → total events that day (questions + flashcards). The
    engine caps this to the last 30 entries — older dates are pruned on
    each write so the doc stays bounded."""

    daily_xp: dict[str, int] = Field(default_factory=dict)
    """ISO date to net XP applied that day. Values use the same
    floor-at-zero rules as ``xp_this_week`` so the weekly chart and XP
    counter stay synchronized. The engine retains the latest 30 dates."""

    # Leaderboard
    leaderboard_rank: int | None = None
