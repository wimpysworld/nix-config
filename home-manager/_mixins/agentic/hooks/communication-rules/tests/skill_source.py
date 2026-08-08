"""Materialise the canonical Communication Rules body for tests."""

from __future__ import annotations

import atexit
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
# The house style is a complete output style file. The deployed hook receives
# its body with the frontmatter stripped by ``compose.nix``, which
# ``fragment.nix`` shares, so the tests strip it the same way.
HOUSE_STYLE = ROOT.parents[1] / "assistants/styles/house-style/house-style.md"


def _strip_frontmatter(text: str) -> str:
    """Drop a leading YAML frontmatter block, mirroring ``compose.nix``."""
    if not text.startswith("---\n"):
        return text
    closing = text.find("\n---\n", len("---\n") - 1)
    if closing == -1:
        return text
    return text[closing + len("\n---\n") :]


def skill_body() -> str:
    """Return the canonical rules body."""
    return _strip_frontmatter(HOUSE_STYLE.read_text(encoding="utf-8")).strip()


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
