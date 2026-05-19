"""Prompt files for the ingestion + question-generation pipelines.

Per ``.claude/rules/ai-prompts.md`` every prompt lives in its own ``.txt``
file with a version header. This package exposes a small loader so callers
don't have to know the on-disk path or hand-roll Jinja-style substitution.

Sprint 3.7 kept the question-generation prompts here (alongside the
Sprint 2 ingestion prompts) rather than in a separate MCP server. The
hybrid MCP layer (see ``app/mcp_tools/``) calls into them in-process;
when we lift to a standalone MCP server later, this directory moves
with the tools.
"""

from __future__ import annotations

from pathlib import Path

_PROMPTS_DIR = Path(__file__).resolve().parent


def load_prompt(name: str) -> str:
    """Return the raw text of a prompt file (no substitution).

    Args:
        name: filename without extension, e.g. ``"topic_extraction_v1"``.

    Raises:
        FileNotFoundError: if the prompt doesn't exist. We do NOT fall back —
            a missing prompt is a deploy bug, not a runtime branch.
    """
    path = _PROMPTS_DIR / f"{name}.txt"
    return path.read_text(encoding="utf-8")


def render(template: str, **variables: object) -> str:
    """Substitute ``{{var}}`` placeholders in ``template`` with values.

    Single-pass, no escaping, no conditionals — keep prompts a flat string with
    explicit holes. If the prompt needs branching, write two prompts.
    """
    out = template
    for key, value in variables.items():
        out = out.replace(f"{{{{{key}}}}}", str(value))
    return out


def split_system_user(template: str) -> tuple[str, str]:
    """Split a prompt file into its system / user halves.

    Convention (matches the .txt files in this directory):
        [SYSTEM]
        ...
        [USER]
        ...

    Raises:
        ValueError: if the file doesn't contain both markers.
    """
    if "[SYSTEM]" not in template or "[USER]" not in template:
        raise ValueError(
            "Prompt must contain [SYSTEM] and [USER] section markers"
        )
    _, _, rest = template.partition("[SYSTEM]")
    system_part, _, user_part = rest.partition("[USER]")
    return system_part.strip(), user_part.strip()
