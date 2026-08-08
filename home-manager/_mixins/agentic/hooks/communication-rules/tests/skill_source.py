"""Materialise the canonical Communication Rules body for tests."""

from __future__ import annotations

import atexit
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
# The house style is the canonical rules body, the same file ``fragment.nix``
# reads. It carries no frontmatter, so it is used verbatim.
HOUSE_STYLE = ROOT.parents[1] / "assistants/styles/house-style/house-style.md"


def skill_body() -> str:
    """Return the canonical rules body."""
    return HOUSE_STYLE.read_text(encoding="utf-8").strip()


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
