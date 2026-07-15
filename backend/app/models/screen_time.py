"""Screen time models — cloud-backed settings and wallet.

Two documents:

- ``ScreenTimeSettings`` — one per workspace.  Controlled by workspace /
  tenant admin.  Drives what the student-facing Accessibility Service
  enforces; Flutter syncs this into SharedPreferences on startup so the
  native service can read it without network calls.

- ``ScreenTimeWallet`` — one per (student, workspace).  Tracks how many
  screen-time minutes a student has earned (from XP) and consumed.
"""

from __future__ import annotations

from pydantic import Field

from app.models.base import CosmosDocument

# Default list of social-media packages to block when a workspace has
# not yet configured a custom list.
_DEFAULT_BLOCKED_PACKAGES: list[str] = [
    "com.instagram.android",
    "com.instagram.barcelona",  # Threads
    "com.zhiliaoapp.musically",  # TikTok
    "com.google.android.youtube",
    "com.facebook.katana",
    "com.twitter.android",
    "com.snapchat.android",
    "com.reddit.frontpage",
    "com.pinterest",
]

# Default XP needed to earn one minute of screen time.
_DEFAULT_XP_TO_MINUTE_RATIO: int = 10


class ScreenTimeSettings(CosmosDocument):
    """Workspace-level screen time configuration.

    Partition key: workspace_id.
    One document per workspace — upserted on first admin write.

    The ``_id`` is set to ``f"sts_{workspace_id}"`` so there is always
    at most one settings doc per workspace and point reads are O(1)
    without a secondary index.
    """

    tenant_id: str
    workspace_id: str

    enable_blocking: bool = True
    """When False the Accessibility Service passes all apps through
    regardless of wallet balance.  Lets admins temporarily disable
    blocking (e.g. exam day) without clearing the wallet."""

    blocked_packages: list[str] = Field(default_factory=lambda: list(_DEFAULT_BLOCKED_PACKAGES))
    """Android package names to block.  Workspace admin controls this
    list; students see it read-only."""

    xp_to_minute_ratio: int = _DEFAULT_XP_TO_MINUTE_RATIO
    """XP required to earn one minute of screen time.
    Default 10 XP = 1 minute."""


class ScreenTimeWallet(CosmosDocument):
    """Per-(student, workspace) screen time balance.

    Partition key: student_id.
    One document per (student, workspace) pair — upserted on first sync.

    The ``_id`` is set to ``f"stw_{student_id}_{workspace_id}"`` so
    point reads are O(1) without a secondary index.
    """

    tenant_id: str
    workspace_id: str
    student_id: str

    # Earned balance
    total_earned_minutes: int = 0
    """Cumulative minutes earned across all time (monotonically increasing)."""

    available_minutes: int = 0
    """Minutes currently available to spend (total_earned - consumed)."""

    # Consumed balance
    consumed_minutes: int = 0
    """Total minutes consumed across all time."""

    consumed_today: int = 0
    """Minutes consumed since last_reset_date (resets at midnight)."""

    last_reset_date: str | None = None
    """ISO date (YYYY-MM-DD) of the last daily-reset.  When the server
    sees a wallet whose last_reset_date is before today it zeros
    consumed_today before returning."""

    # XP tracking (for sync-xp recalculation)
    last_known_xp: int = 0
    """The XP total that was used in the last sync.  Used to compute the
    delta when the student earns more XP."""

    last_sync_time: str | None = None
    """ISO timestamp of the last time this wallet was written."""
