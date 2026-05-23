"""Badge catalog and unlock evaluator — Sprint 5.3.

Static catalog of 17 badge definitions plus :func:`evaluate_badges`,
which compares a student's current :class:`GamificationState` against
their already-earned badges and returns the freshly-unlocked
definitions.

Trigger model
-------------
Every badge has a ``trigger`` predicate over a
:class:`GamificationState`. The engine calls :func:`evaluate_badges`
*after* applying the latest event's effects (XP, streak, counters), so
the predicate sees post-event state. Predicates are intentionally
side-effect-free — they don't read knowledge_state, interactions, or
any other collection — so badge logic stays unit-testable without I/O.

Mastery-tier badges (e.g. "reach 80% in a topic") are deferred to a
later sprint: they need a knowledge_state read, which would couple
this evaluator to the DB. The v1 catalog covers XP, streak,
questions_answered / correct, flashcards_reviewed, and level — every
counter that already lives on the gamification doc.

Icons
-----
``icon`` is a Material Icons name string (no leading ``Icons.``) so
the Flutter UI can resolve it via a ``Map<String, IconData>`` lookup
without round-tripping codepoints. Names track the official Flutter
``Icons.*_rounded`` set so they render consistently in the badge grid.
"""

from __future__ import annotations

from collections.abc import Callable
from dataclasses import dataclass

from app.models.gamification import GamificationState


@dataclass(frozen=True, slots=True)
class BadgeDefinition:
    """Static metadata + trigger predicate for one earnable badge.

    Stored in :data:`BADGES` and looked up by ``badge_id``. The engine
    materialises an earned badge by copying ``id``/``name``/
    ``description``/``icon`` into a :class:`app.models.gamification.Badge`
    record on the student's gamification doc — the predicate isn't
    persisted.
    """

    id: str
    name: str
    description: str
    icon: str
    trigger: Callable[[GamificationState], bool]


# ── Catalog ─────────────────────────────────────────────────────────────────

# Ordered roughly by difficulty within each progression so the badge
# showcase grid can render them in a sensible default sort. Stable
# ordering also makes the unlock-order assertions in tests
# deterministic.
BADGES: tuple[BadgeDefinition, ...] = (
    # First-time milestones
    BadgeDefinition(
        id="first_steps",
        name="First Steps",
        description="Answer your first question.",
        icon="spa_rounded",
        trigger=lambda s: s.questions_answered >= 1,
    ),
    BadgeDefinition(
        id="first_flashcard",
        name="Flip Side",
        description="Review your first flashcard.",
        icon="style_rounded",
        trigger=lambda s: s.flashcards_reviewed >= 1,
    ),
    # Streak progression
    BadgeDefinition(
        id="streak_3",
        name="Warming Up",
        description="Study three days in a row.",
        icon="whatshot_rounded",
        trigger=lambda s: s.streak_days >= 3,
    ),
    BadgeDefinition(
        id="streak_7",
        name="Dedicated",
        description="Maintain a seven-day study streak.",
        icon="local_fire_department_rounded",
        trigger=lambda s: s.streak_days >= 7,
    ),
    BadgeDefinition(
        id="streak_30",
        name="Committed",
        description="Maintain a thirty-day study streak.",
        icon="emoji_events_rounded",
        trigger=lambda s: s.streak_days >= 30,
    ),
    BadgeDefinition(
        id="streak_100",
        name="Marathoner",
        description="Maintain a hundred-day study streak.",
        icon="military_tech_rounded",
        trigger=lambda s: s.streak_days >= 100,
    ),
    # Volume — questions answered
    BadgeDefinition(
        id="scholar_25",
        name="Scholar",
        description="Answer 25 questions.",
        icon="menu_book_rounded",
        trigger=lambda s: s.questions_answered >= 25,
    ),
    BadgeDefinition(
        id="scholar_100",
        name="Honor Student",
        description="Answer 100 questions.",
        icon="school_rounded",
        trigger=lambda s: s.questions_answered >= 100,
    ),
    BadgeDefinition(
        id="scholar_500",
        name="Star Pupil",
        description="Answer 500 questions.",
        icon="auto_awesome_rounded",
        trigger=lambda s: s.questions_answered >= 500,
    ),
    # Accuracy — questions correct
    BadgeDefinition(
        id="sharp_5",
        name="Sharp",
        description="Answer five questions correctly.",
        icon="adjust_rounded",
        trigger=lambda s: s.questions_correct >= 5,
    ),
    BadgeDefinition(
        id="sharp_50",
        name="Sharpshooter",
        description="Answer fifty questions correctly.",
        icon="gps_fixed_rounded",
        trigger=lambda s: s.questions_correct >= 50,
    ),
    BadgeDefinition(
        id="perfectionist",
        name="Perfectionist",
        description="Maintain 90% accuracy over 50+ questions.",
        icon="workspace_premium_rounded",
        # Guard: avoid div-by-zero. The questions_answered>=50 clause
        # already implies non-zero, but the explicit guard makes the
        # invariant local + the predicate safe to call on any state.
        trigger=lambda s: (
            s.questions_answered >= 50
            and s.questions_correct / max(s.questions_answered, 1) >= 0.9
        ),
    ),
    # XP totals
    BadgeDefinition(
        id="xp_100",
        name="Rising Star",
        description="Earn 100 XP.",
        icon="star_rounded",
        trigger=lambda s: s.xp_total >= 100,
    ),
    BadgeDefinition(
        id="xp_1000",
        name="XP Powerhouse",
        description="Earn 1,000 XP.",
        icon="bolt_rounded",
        trigger=lambda s: s.xp_total >= 1_000,
    ),
    BadgeDefinition(
        id="xp_10000",
        name="XP Legend",
        description="Earn 10,000 XP.",
        icon="trophy_rounded",
        trigger=lambda s: s.xp_total >= 10_000,
    ),
    # Flashcard volume
    BadgeDefinition(
        id="flashcard_fan",
        name="Flashcard Fan",
        description="Review 50 flashcards.",
        icon="filter_drama_rounded",
        trigger=lambda s: s.flashcards_reviewed >= 50,
    ),
    BadgeDefinition(
        id="flashcard_master",
        name="Memory Master",
        description="Review 250 flashcards.",
        icon="psychology_rounded",
        trigger=lambda s: s.flashcards_reviewed >= 250,
    ),
    # Level
    BadgeDefinition(
        id="level_5",
        name="Apprentice",
        description="Reach level 5.",
        icon="emoji_events_outlined",
        trigger=lambda s: s.level >= 5,
    ),
    BadgeDefinition(
        id="level_10",
        name="Adept",
        description="Reach level 10.",
        icon="auto_stories_rounded",
        trigger=lambda s: s.level >= 10,
    ),
)


# ── Index built once at import time ─────────────────────────────────────────

_BY_ID: dict[str, BadgeDefinition] = {b.id: b for b in BADGES}


def by_id(badge_id: str) -> BadgeDefinition | None:
    """Look up a badge definition by ``badge_id`` (or ``None`` if unknown).

    Useful when reconstructing badge metadata for the gamification API
    response — the persisted :class:`app.models.gamification.Badge`
    already carries name/description/icon, but reading them off the
    catalog keeps a single source of truth for renames.
    """
    return _BY_ID.get(badge_id)


# ── Evaluator ───────────────────────────────────────────────────────────────


def evaluate_badges(state: GamificationState) -> list[BadgeDefinition]:
    """Return the badges newly unlocked by [state]'s current counters.

    Compares each catalog predicate against the post-event state and
    yields only the definitions whose ``id`` isn't already on
    ``state.badges``. Order follows :data:`BADGES` (catalog order), so
    a state crossing two thresholds in one event always reports them
    in the same order — deterministic for tests, predictable for the
    "you unlocked X and Y!" UI banner.

    Pure function: no I/O, no mutation. The engine persists the new
    badges by appending :class:`app.models.gamification.Badge` records
    to ``state.badges``.
    """
    already_earned = {b.badge_id for b in state.badges}
    return [
        definition
        for definition in BADGES
        if definition.id not in already_earned and definition.trigger(state)
    ]
