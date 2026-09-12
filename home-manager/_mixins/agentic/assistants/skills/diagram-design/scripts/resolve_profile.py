"""Resolve a diagram profile without file changes."""

import argparse
import json
from pathlib import Path
import re
import sys


SLUG = r"[a-z0-9][a-z0-9-]{0,63}"
SELECTOR = re.compile(r"[ \t]*profile:[ \t]*(" + SLUG + r")[ \t]*(?:\r?\n)?")


def resolve(project, home, installed, requested=None):
    warnings = []
    slug, source = requested, "request"
    if slug is not None and re.fullmatch(SLUG, slug) is None:
        raise ValueError("Invalid requested profile slug")
    if slug is None:
        for path, source in (
            (project / ".diagram-design", "project"),
            (home / ".diagram-design/preferences", "user"),
        ):
            try:
                content = path.read_text(encoding="utf-8")
            except FileNotFoundError:
                if path.is_symlink():
                    raise ValueError(f"Broken selector symlink: {path}")
                continue
            match = SELECTOR.fullmatch(content)
            if match:
                slug = match[1]
                break
            warnings.append(f"Invalid selector ignored: {path}")
    if slug is None:
        slug, source = "default", "setup"
    path = (
        installed / "references/style-guide.md"
        if slug == "default"
        else home / ".diagram-design/profiles" / f"{slug}.md"
    )
    if not path.is_file():
        raise ValueError(
            f"Missing profile {slug}: {path}. Ask the user and offer list."
        )
    return {"profile": slug, "source": source, "path": str(path), "warnings": warnings}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project-root", type=Path, required=True)
    parser.add_argument("--profile")
    args = parser.parse_args()
    try:
        result = resolve(
            args.project_root,
            Path.home(),
            Path(__file__).absolute().parent.parent,
            args.profile,
        )
    except (OSError, UnicodeError, ValueError) as error:
        print(str(error), file=sys.stderr)
        return 1
    print(json.dumps(result))
    return 0


if __name__ == "__main__":
    sys.exit(main())
