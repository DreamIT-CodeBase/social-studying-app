"""MCP-shaped tool registry — Sprint 3.2 (hybrid in-process variant).

The original sprint plan called for a standalone containerized MCP server
exposing typed tools the FastAPI endpoint would call across an RPC seam.
We deliberately defer that container split (see [[first-real-azure-run-findings]]
for the operational cost of yet another Container App) and instead mount
the same tools as a local Python module the API imports.

The contract is intentionally MCP-shaped so the transition to a real MCP
server is mechanical:

- Each tool registers a ``ToolDefinition`` with a name, description, and
  Pydantic models for input + output. ``input_schema()`` returns the JSON
  Schema the model exposes, which is exactly what an MCP server would
  publish.
- ``invoke(name, params)`` is the universal entry point. It validates
  params against the tool's input model, runs the handler, and returns
  the validated output. Same dispatch shape an MCP transport would use.
- Tools are pure async functions that take a validated input model and
  return a validated output model. No FastAPI / request / response
  knowledge — that lifts cleanly into a separate process later.

How tools are discovered
------------------------
Each tool file calls ``@register_tool(...)`` at import time. To force
the side-effect imports without making every caller list them, this
``__init__`` explicitly imports every tool module below. Adding a new
tool means a new import line here.
"""

from __future__ import annotations

from collections.abc import Awaitable, Callable
from dataclasses import dataclass
from typing import Any

from pydantic import BaseModel


@dataclass(frozen=True, slots=True)
class ToolDefinition:
    """The metadata + handler the registry stores for one tool.

    Mirrors the shape an MCP server would publish (``name`` +
    ``description`` + ``inputSchema``) plus a handler the in-process
    invoker calls directly. The output model is kept for serialization
    + test ergonomics; MCP itself only schematizes inputs.
    """

    name: str
    description: str
    input_model: type[BaseModel]
    output_model: type[BaseModel]
    handler: Callable[[BaseModel], Awaitable[BaseModel]]

    def input_schema(self) -> dict[str, Any]:
        """Return the JSON Schema an MCP server would publish for this tool."""
        return self.input_model.model_json_schema()


# Module-level singleton. Tools register themselves on import via
# ``register_tool``. Lookup is by case-sensitive name — match the wire
# convention MCP uses.
_REGISTRY: dict[str, ToolDefinition] = {}


def register_tool(
    *,
    name: str,
    description: str,
    input_model: type[BaseModel],
    output_model: type[BaseModel],
) -> Callable[
    [Callable[[BaseModel], Awaitable[BaseModel]]],
    Callable[[BaseModel], Awaitable[BaseModel]],
]:
    """Decorator that registers an async handler under ``name``.

    Raises:
        ValueError: if ``name`` is already taken. Duplicate registration
            is always a bug — fail loud at import time rather than silently
            shadowing a tool.
    """

    def _decorator(
        fn: Callable[[BaseModel], Awaitable[BaseModel]],
    ) -> Callable[[BaseModel], Awaitable[BaseModel]]:
        if name in _REGISTRY:
            raise ValueError(
                f"Tool {name!r} is already registered (by "
                f"{_REGISTRY[name].handler.__module__}.{_REGISTRY[name].handler.__qualname__})"
            )
        _REGISTRY[name] = ToolDefinition(
            name=name,
            description=description,
            input_model=input_model,
            output_model=output_model,
            handler=fn,
        )
        return fn

    return _decorator


def list_tools() -> list[ToolDefinition]:
    """Return every registered tool in registration order.

    Stable order matters for any consumer that wants a deterministic
    listing (CLI introspection, MCP server's tools/list response).
    """
    return list(_REGISTRY.values())


def get_tool(name: str) -> ToolDefinition:
    """Return the tool registered as ``name``.

    Raises:
        KeyError: if no tool with that name is registered. Callers should
            handle this and surface a 404-ish error to the requester rather
            than a 500.
    """
    tool = _REGISTRY.get(name)
    if tool is None:
        raise KeyError(f"Unknown tool: {name!r}")
    return tool


async def invoke(name: str, params: dict[str, Any] | BaseModel) -> BaseModel:
    """Validate ``params`` against the tool's input model and run it.

    Accepts either a dict (which gets validated) or a pre-built input
    model instance (which gets re-validated for safety — the cost is
    negligible and it catches accidental mutation between callsites).

    Raises:
        KeyError: tool name not registered.
        pydantic.ValidationError: params don't match the tool's input
            schema. Caller is responsible for mapping to a user-facing
            error.

    The handler may raise its own exceptions (transient backend errors,
    domain-specific failures) — those propagate unchanged.
    """
    tool = get_tool(name)
    if isinstance(params, tool.input_model):
        validated = params
    elif isinstance(params, BaseModel):
        validated = tool.input_model.model_validate(params.model_dump())
    else:
        validated = tool.input_model.model_validate(params)
    return await tool.handler(validated)


# ── Tool registration ────────────────────────────────────────────────────────
# Importing each tool module triggers its @register_tool side-effect. Keep
# this list synced with the directory contents; missing imports = silently
# unavailable tools.

from app.mcp_tools import (  # noqa: E402
    retrieve_content,  # noqa: F401
    retrieve_student_context,  # noqa: F401
)

__all__ = [
    "ToolDefinition",
    "register_tool",
    "list_tools",
    "get_tool",
    "invoke",
]
