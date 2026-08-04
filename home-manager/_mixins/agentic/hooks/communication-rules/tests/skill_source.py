"""Materialise the canonical Communication Rules skill body for tests."""

from __future__ import annotations

import atexit
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SKILL = ROOT.parents[1] / "assistants/skills/communication-rules/SKILL.md"


def skill_body() -> str:
    """Return the skill body without portable YAML frontmatter."""
    source = SKILL.read_text(encoding="utf-8")
    parts = source.split("\n---\n")
    frontmatter = parts[0]
    if (
        len(parts) < 2
        or not frontmatter.startswith("---\n")
        or "\nname: communication-rules" not in frontmatter
        or "\ndescription:" not in frontmatter
    ):
        raise ValueError(f"Invalid Communication Rules skill frontmatter: {SKILL}")
    return "\n---\n".join(parts[1:]).strip()


def materialised_rules_path() -> Path:
    """Write the raw skill body to a temporary scanner input file."""
    handle = tempfile.NamedTemporaryFile(
        mode="w", encoding="utf-8", prefix="communication-rules-", suffix=".md", delete=False
    )
    with handle:
        handle.write(f"{skill_body()}\n")
    path = Path(handle.name)
    atexit.register(path.unlink, missing_ok=True)
    return path
