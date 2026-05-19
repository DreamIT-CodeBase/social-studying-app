"""Unit tests for the MCP-shaped tool registry.

The registry is the single dispatch seam every tool ships through, so
these tests pin both the happy path and the cases where the system would
be most confused: unknown tools, double-registration, bad input shapes.

The shared ``_REGISTRY`` global is used by the real tools too, so each
test that mutates it does so under a unique name and patches the module
attribute directly when isolation is needed.
"""

from __future__ import annotations

from typing import Any

import pytest
from pydantic import BaseModel, ValidationError

from app import mcp_tools
from app.mcp_tools import (
    ToolDefinition,
    get_tool,
    invoke,
    list_tools,
    register_tool,
)

# ── Fixtures ────────────────────────────────────────────────────────────────


@pytest.fixture
def isolated_registry(monkeypatch):
    """Swap ``_REGISTRY`` for a fresh dict so tests can register freely."""
    monkeypatch.setattr(mcp_tools, "_REGISTRY", {})
    yield


# Two tiny models used across multiple tests.


class _ToyInput(BaseModel):
    name: str
    times: int = 1


class _ToyOutput(BaseModel):
    echo: str
    count: int


# ── Registration ────────────────────────────────────────────────────────────


def test_register_tool_stores_definition_under_name(isolated_registry):
    @register_tool(
        name="toy_echo",
        description="Echo a name N times.",
        input_model=_ToyInput,
        output_model=_ToyOutput,
    )
    async def _handler(params: _ToyInput) -> _ToyOutput:
        return _ToyOutput(echo=params.name, count=params.times)

    tool = get_tool("toy_echo")
    assert isinstance(tool, ToolDefinition)
    assert tool.name == "toy_echo"
    assert tool.description.startswith("Echo")
    assert tool.input_model is _ToyInput
    assert tool.output_model is _ToyOutput


def test_register_tool_rejects_duplicate_name(isolated_registry):
    @register_tool(
        name="dup",
        description="first",
        input_model=_ToyInput,
        output_model=_ToyOutput,
    )
    async def _first(params: _ToyInput) -> _ToyOutput:  # noqa: D401
        return _ToyOutput(echo="a", count=1)

    with pytest.raises(ValueError, match="already registered"):

        @register_tool(
            name="dup",
            description="second",
            input_model=_ToyInput,
            output_model=_ToyOutput,
        )
        async def _second(params: _ToyInput) -> _ToyOutput:
            return _ToyOutput(echo="b", count=2)


def test_input_schema_is_json_schema_shaped(isolated_registry):
    @register_tool(
        name="schema_check",
        description="x",
        input_model=_ToyInput,
        output_model=_ToyOutput,
    )
    async def _handler(params: _ToyInput) -> _ToyOutput:
        return _ToyOutput(echo=params.name, count=params.times)

    schema = get_tool("schema_check").input_schema()
    assert schema["type"] == "object"
    assert "name" in schema["properties"]
    assert "times" in schema["properties"]
    # Required field is enforced; optional with default isn't.
    assert "name" in schema.get("required", [])
    assert "times" not in schema.get("required", [])


# ── Discovery ───────────────────────────────────────────────────────────────


def test_list_tools_returns_registration_order(isolated_registry):
    @register_tool(
        name="first",
        description="x",
        input_model=_ToyInput,
        output_model=_ToyOutput,
    )
    async def _f(p: _ToyInput) -> _ToyOutput:
        return _ToyOutput(echo="", count=0)

    @register_tool(
        name="second",
        description="y",
        input_model=_ToyInput,
        output_model=_ToyOutput,
    )
    async def _g(p: _ToyInput) -> _ToyOutput:
        return _ToyOutput(echo="", count=0)

    names = [t.name for t in list_tools()]
    assert names == ["first", "second"]


def test_get_tool_raises_keyerror_for_unknown(isolated_registry):
    with pytest.raises(KeyError, match="Unknown tool"):
        get_tool("nope")


# ── Invocation ──────────────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_invoke_validates_dict_params_and_runs_handler(isolated_registry):
    captured: dict[str, Any] = {}

    @register_tool(
        name="cap",
        description="capture",
        input_model=_ToyInput,
        output_model=_ToyOutput,
    )
    async def _handler(params: _ToyInput) -> _ToyOutput:
        captured["name"] = params.name
        captured["times"] = params.times
        return _ToyOutput(echo=params.name, count=params.times)

    result = await invoke("cap", {"name": "hello", "times": 3})

    assert isinstance(result, _ToyOutput)
    assert result.echo == "hello"
    assert result.count == 3
    assert captured == {"name": "hello", "times": 3}


@pytest.mark.asyncio
async def test_invoke_accepts_pre_built_input_model(isolated_registry):
    """Callers that already have an input model should be able to pass it
    in directly. We re-validate (cheap) to catch any accidental mutation
    between callsites.
    """

    @register_tool(
        name="passthrough",
        description="x",
        input_model=_ToyInput,
        output_model=_ToyOutput,
    )
    async def _handler(params: _ToyInput) -> _ToyOutput:
        return _ToyOutput(echo=params.name, count=params.times)

    result = await invoke("passthrough", _ToyInput(name="prebuilt", times=2))
    assert result.echo == "prebuilt"
    assert result.count == 2


@pytest.mark.asyncio
async def test_invoke_raises_validation_error_on_bad_params(isolated_registry):
    @register_tool(
        name="validates",
        description="x",
        input_model=_ToyInput,
        output_model=_ToyOutput,
    )
    async def _handler(params: _ToyInput) -> _ToyOutput:
        return _ToyOutput(echo=params.name, count=params.times)

    with pytest.raises(ValidationError):
        # 'name' is required; sending only 'times' must blow up at the
        # validator, before the handler is invoked.
        await invoke("validates", {"times": 5})


@pytest.mark.asyncio
async def test_invoke_raises_keyerror_on_unknown_tool(isolated_registry):
    with pytest.raises(KeyError, match="Unknown tool"):
        await invoke("ghost", {"name": "x"})


@pytest.mark.asyncio
async def test_invoke_propagates_handler_exceptions(isolated_registry):
    """Handler errors must surface unchanged — the registry is dispatch,
    not error-handling. Callers translate to user-facing errors.
    """

    class _Boom(RuntimeError):
        pass

    @register_tool(
        name="explodes",
        description="x",
        input_model=_ToyInput,
        output_model=_ToyOutput,
    )
    async def _handler(params: _ToyInput) -> _ToyOutput:
        raise _Boom("intentional")

    with pytest.raises(_Boom, match="intentional"):
        await invoke("explodes", {"name": "x"})


# ── Discovery of the real tools ─────────────────────────────────────────────


def test_real_tools_register_on_import():
    """Importing ``app.mcp_tools`` should make the production tools
    discoverable — the dispatch is useless if a tool doesn't show up
    until the API has already booted.
    """
    names = {t.name for t in list_tools()}
    # Sprint 3.5 + 3.6
    assert "retrieve_content" in names
    assert "retrieve_student_context" in names
