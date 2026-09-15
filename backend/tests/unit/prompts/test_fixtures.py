"""Structural validation for the prompt eval fixtures (Sprint 6.14).

The fixtures themselves don't call OpenAI — they're the *inputs* the
``/prompt-eval`` skill loads when an engineer changes a prompt. This
test pins their structural contract so a typo in a fixture file
(missing field, wrong type, no test cases) fails fast at CI time,
not at eval time.

The contract:

* Every prompt with a ``v1`` template under ``app/prompts/`` has a
  matching fixture file under ``app/prompts/fixtures/``.
* Each fixture file lists ``prompt``, ``description``, and a
  ``cases`` array of 5+ test cases.
* Each case has a ``name``, an ``input`` object whose keys are a
  subset of the prompt's template variables, and a
  ``expected_constraints`` list of human-readable invariants.
"""

from __future__ import annotations

import json
import re
from pathlib import Path

import pytest

PROMPTS_DIR = Path(__file__).resolve().parents[3] / "app" / "prompts"
FIXTURES_DIR = PROMPTS_DIR / "fixtures"


def _template_variables(prompt_path: Path) -> set[str]:
    """Extract ``{{variable}}`` placeholders from the prompt text."""
    text = prompt_path.read_text(encoding="utf-8")
    return set(re.findall(r"\{\{\s*(\w+)\s*\}\}", text))


def _prompt_files() -> list[Path]:
    """Every ``*_v<n>.txt`` prompt template under ``app/prompts/``."""
    return sorted(p for p in PROMPTS_DIR.glob("*_v*.txt") if p.is_file())


def _fixture_files() -> list[Path]:
    return sorted(FIXTURES_DIR.glob("*.json"))


def _load_fixture(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


# ── Coverage: every prompt has a fixture file ─────────────────────────────


def test_every_prompt_has_a_fixture_file():
    """``question_mcq_v1.txt`` → ``fixtures/question_mcq.json``. The
    version suffix isn't included in the fixture filename; one fixture
    file is the source of truth across versions of the same prompt."""
    fixture_stems = {p.stem for p in _fixture_files()}
    for prompt in _prompt_files():
        # Strip the trailing ``_v<digits>`` to match the fixture name.
        base = re.sub(r"_v\d+$", "", prompt.stem)
        assert base in fixture_stems, (
            f"prompt {prompt.name} has no matching fixture {base}.json under {FIXTURES_DIR}"
        )


# ── Per-fixture structural checks ────────────────────────────────────────


@pytest.mark.parametrize(
    "fixture_path",
    _fixture_files(),
    ids=lambda p: p.name,
)
def test_fixture_has_required_top_level_keys(fixture_path: Path):
    payload = _load_fixture(fixture_path)
    for key in ("prompt", "description", "cases"):
        assert key in payload, f"missing key {key!r}"
    assert isinstance(payload["cases"], list)


@pytest.mark.parametrize(
    "fixture_path",
    _fixture_files(),
    ids=lambda p: p.name,
)
def test_fixture_has_at_least_five_cases(fixture_path: Path):
    """The ``/prompt-eval`` skill prescribes 5 diverse inputs minimum:
    happy / very-short / very-long / different-subject / ambiguous."""
    payload = _load_fixture(fixture_path)
    assert len(payload["cases"]) >= 5, (
        f"{fixture_path.name} has {len(payload['cases'])} cases; "
        "need >= 5 (one per /prompt-eval diversity slot)."
    )


@pytest.mark.parametrize(
    "fixture_path",
    _fixture_files(),
    ids=lambda p: p.name,
)
def test_fixture_case_names_are_unique(fixture_path: Path):
    payload = _load_fixture(fixture_path)
    names = [case.get("name") for case in payload["cases"]]
    assert len(names) == len(set(names)), f"{fixture_path.name} has duplicate case names: {names}"


@pytest.mark.parametrize(
    "fixture_path",
    _fixture_files(),
    ids=lambda p: p.name,
)
def test_fixture_cases_have_required_shape(fixture_path: Path):
    payload = _load_fixture(fixture_path)
    for case in payload["cases"]:
        assert "name" in case
        assert "input" in case
        assert "expected_constraints" in case
        assert isinstance(case["input"], dict)
        assert isinstance(case["expected_constraints"], list)
        assert case["expected_constraints"], (
            f"{fixture_path.name}::{case['name']} has no constraints"
        )


@pytest.mark.parametrize(
    "fixture_path",
    _fixture_files(),
    ids=lambda p: p.name,
)
def test_fixture_inputs_match_a_prompt_template(fixture_path: Path):
    """Every input key must appear as a ``{{variable}}`` placeholder in
    the prompt template — typos in the fixture key would mean the
    eval harness ships missing input to the model."""
    fixture = _load_fixture(fixture_path)
    base_name = fixture_path.stem  # e.g. "question_mcq"
    # Find the highest-version prompt template for this fixture.
    candidates = sorted(PROMPTS_DIR.glob(f"{base_name}_v*.txt"))
    assert candidates, f"no prompt template found for fixture {fixture_path.name}"
    template = candidates[-1]
    variables = _template_variables(template)
    for case in fixture["cases"]:
        for key in case["input"]:
            assert key in variables, (
                f"{fixture_path.name}::{case['name']} input key {key!r} "
                f"is not a template variable in {template.name}. "
                f"Known variables: {sorted(variables)}"
            )
