"""Guard the boundary between local inline workers and deployed workers."""

from __future__ import annotations

from unittest.mock import AsyncMock, patch

import pytest

from app.main import app, lifespan


@pytest.mark.asyncio
async def test_lifespan_does_not_start_inline_workers_unless_explicitly_enabled():
    """A development API must not compete with the dedicated worker apps."""
    with (
        patch("app.main.get_redis", new_callable=AsyncMock),
        patch("app.main.close_redis", new_callable=AsyncMock),
        patch("app.main.settings.inline_workers_enabled", False),
        patch("app.main.settings.service_bus_connection", "Endpoint=sb://test"),
        patch("app.main.asyncio.create_task") as create_task,
    ):
        async with lifespan(app):
            pass

    create_task.assert_not_called()
