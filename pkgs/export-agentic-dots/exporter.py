#!/usr/bin/env python3
"""Export a generated agentic-dots manifest without overwriting unowned data."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import shutil
import stat
import sys
import tempfile
from contextlib import suppress
from pathlib import Path, PurePosixPath
from typing import Any

OWNERSHIP_FILE = ".agentic-dots-manifest.json"
OWNERSHIP_TEMP_FILE = f".{OWNERSHIP_FILE}.new"
OUTPUT_TEMP_SUFFIX = ".agentic-dots-new"
UNSAFE_REFERENCES = (b"/nix/store/", b"/home/", b"sops.placeholder")
SAFE_PROSE_REFERENCES = {
    "skills/gh/SKILL.md": {
        b'gh search code "sops.placeholder" --repo owner/repo --language nix',
    },
}


class ExportError(RuntimeError):
    """A safe export could not continue."""


def file_hash(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def content_hash(content: bytes) -> str:
    return hashlib.sha256(content).hexdigest()


def safe_relative_path(value: object) -> PurePosixPath:
    if not isinstance(value, str) or not value:
        raise ExportError("manifest paths must be non-empty strings")
    path = PurePosixPath(value)
    if path.is_absolute() or ".." in path.parts or "." in path.parts or not path.parts:
        raise ExportError(f"unsafe manifest path: {value!r}")
    if any(not part or "\\" in part for part in path.parts):
        raise ExportError(f"unsafe manifest path: {value!r}")
    return path


def read_manifest(path: Path) -> dict[str, Any]:
    try:
        manifest = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise ExportError(f"cannot read manifest {path}: {error}") from error
    if not isinstance(manifest, dict) or manifest.get("schemaVersion") != 1:
        raise ExportError(f"unsupported manifest schema in {path}")
    if not isinstance(manifest.get("files"), list):
        raise ExportError(f"manifest files must be a list in {path}")
    return manifest


def validate_safe_references(
    path: PurePosixPath, content: bytes, *, allow_prose: bool
) -> None:
    prose_key = "/".join(path.parts[-3:])
    allowed_lines = (
        SAFE_PROSE_REFERENCES.get(prose_key, set()) if allow_prose else set()
    )
    for line in content.splitlines():
        for marker in UNSAFE_REFERENCES:
            if marker in line and line.strip() not in allowed_lines:
                reference = marker.decode("ascii")
                raise ExportError(
                    f"unsafe reference {reference!r} in {path.as_posix()}"
                )


def normalise_entries(manifest: dict[str, Any]) -> list[dict[str, Any]]:
    entries: list[dict[str, Any]] = []
    seen: set[str] = set()
    for raw in manifest["files"]:
        if not isinstance(raw, dict):
            raise ExportError("manifest file entries must be objects")
        relative = safe_relative_path(raw.get("path"))
        key = relative.as_posix()
        if relative.parts[0] in {OWNERSHIP_FILE, OWNERSHIP_TEMP_FILE} or key in seen:
            raise ExportError(f"duplicate or reserved manifest path: {key}")
        seen.add(key)
        content = raw.get("content")
        mode = raw.get("mode")
        dependencies = raw.get("dependencies")
        if not isinstance(content, str):
            raise ExportError(f"manifest content must be text: {key}")
        if mode not in {"0644", "0755"}:
            raise ExportError(f"unsupported mode for {key}: {mode!r}")
        if not isinstance(dependencies, list) or not all(
            isinstance(item, str) for item in dependencies
        ):
            raise ExportError(f"manifest dependencies must be strings: {key}")
        encoded = content.encode("utf-8")
        validate_safe_references(relative, encoded, allow_prose=True)
        for dependency in dependencies:
            validate_safe_references(
                relative, dependency.encode("utf-8"), allow_prose=False
            )
        entries.append(
            {
                "path": key,
                "relative": relative,
                "content": encoded,
                "mode": mode,
                "dependencies": dependencies,
                "sha256": content_hash(encoded),
            }
        )

    paths = {entry["relative"] for entry in entries}
    for path in paths:
        for length in range(1, len(path.parts)):
            if PurePosixPath(*path.parts[:length]) in paths:
                raise ExportError(
                    f"manifest file and directory paths conflict: {path.as_posix()}"
                )
        temporary = path.with_name(f".{path.name}{OUTPUT_TEMP_SUFFIX}")
        if any(
            candidate == temporary or temporary in candidate.parents
            for candidate in paths
        ):
            raise ExportError(
                f"manifest path conflicts with temporary output: {temporary.as_posix()}"
            )

    return sorted(entries, key=lambda entry: entry["path"])


def ensure_safe_destination(destination: Path) -> None:
    chain = reversed((destination, *destination.parents))
    for candidate in chain:
        if candidate.is_symlink():
            raise ExportError(
                f"symbolic links are not allowed in the destination: {candidate}"
            )
        if candidate.exists() and not candidate.is_dir():
            raise ExportError(
                f"destination parent is not a safe directory: {candidate}"
            )
    if destination.exists():
        for root, directories, files in os.walk(destination, followlinks=False):
            base = Path(root)
            for name in directories + files:
                candidate = base / name
                if candidate.is_symlink():
                    raise ExportError(
                        f"symbolic links are not allowed in the destination: {candidate}"
                    )


def stage(entries: list[dict[str, Any]], parent: Path) -> Path:
    staging = Path(tempfile.mkdtemp(prefix=".agentic-dots-stage-", dir=parent))
    try:
        for entry in entries:
            output = staging.joinpath(*entry["relative"].parts)
            output.parent.mkdir(parents=True, exist_ok=True)
            output.write_bytes(entry["content"])
            output.chmod(int(entry["mode"], 8))
            if file_hash(output) != entry["sha256"]:
                raise ExportError(f"staged hash mismatch: {entry['path']}")
    except Exception:
        shutil.rmtree(staging, ignore_errors=True)
        raise
    return staging


def old_files(destination: Path) -> dict[str, dict[str, Any]]:
    ownership = destination / OWNERSHIP_FILE
    if not ownership.exists():
        if destination.exists() and any(destination.iterdir()):
            raise ExportError(f"destination is not an owned export: {destination}")
        return {}
    manifest = read_manifest(ownership)
    result: dict[str, dict[str, Any]] = {}
    for entry in manifest["files"]:
        if not isinstance(entry, dict):
            raise ExportError(f"invalid owned file entry in {ownership}")
        relative = safe_relative_path(entry.get("path"))
        key = relative.as_posix()
        digest = entry.get("sha256")
        if key in result or not isinstance(digest, str) or len(digest) != 64:
            raise ExportError(f"invalid owned file entry for {key}")
        result[key] = entry
    return result


def validate_conflicts(
    destination: Path,
    entries: list[dict[str, Any]],
    owned: dict[str, dict[str, Any]],
) -> None:
    for entry in entries:
        target = destination.joinpath(*entry["relative"].parts)
        current = destination
        for part in entry["relative"].parts[:-1]:
            current /= part
            if current.exists() and not current.is_dir():
                raise ExportError(f"output parent conflicts with a file: {current}")
        if not target.exists():
            continue
        if not target.is_file():
            raise ExportError(f"output conflicts with a non-file: {target}")
        if entry["path"] not in owned:
            raise ExportError(f"output conflicts with unowned data: {target}")
        if file_hash(target) != owned[entry["path"]]["sha256"]:
            raise ExportError(f"owned output has local changes: {target}")


def output_temporary_path(target: Path) -> Path:
    return target.with_name(f".{target.name}{OUTPUT_TEMP_SUFFIX}")


def validate_temporary_conflicts(
    destination: Path, entries: list[dict[str, Any]]
) -> None:
    temporaries = [
        output_temporary_path(destination.joinpath(*entry["relative"].parts))
        for entry in entries
    ]
    temporaries.append(destination / OWNERSHIP_TEMP_FILE)
    for temporary in temporaries:
        if temporary.exists() or temporary.is_symlink():
            raise ExportError(f"temporary output already exists: {temporary}")


def rollback_outputs(
    applied: list[tuple[dict[str, Any], Path]], backups: dict[str, Path]
) -> list[str]:
    errors: list[str] = []
    for entry, target in reversed(applied):
        backup = backups.get(entry["path"])
        try:
            target_present = target.exists() or target.is_symlink()
            if target_present and (
                target.is_symlink()
                or not target.is_file()
                or file_hash(target) != entry["sha256"]
            ):
                errors.append(f"changed during rollback: {target}")
                continue
            if backup is not None:
                os.replace(backup, target)
            elif target.exists():
                target.unlink()
        except OSError as error:
            errors.append(f"cannot restore {target}: {error}")
    return errors


def ownership_manifest(
    source: dict[str, Any], entries: list[dict[str, Any]], source_revision: str | None
) -> bytes:
    revision = source_revision or source.get("sourceRevision")
    if not isinstance(revision, str) or revision in {"", "unknown", "runtime-required"}:
        raise ExportError("a concrete source revision is required")
    value = {
        "schemaVersion": 1,
        "sourceRevision": revision,
        "policy": source.get("policy", "explicit-public-allowlist"),
        "files": [
            {
                "path": entry["path"],
                "mode": entry["mode"],
                "dependencies": entry["dependencies"],
                "sha256": entry["sha256"],
            }
            for entry in entries
        ],
    }
    return (json.dumps(value, indent=2, sort_keys=True) + "\n").encode("utf-8")


def export(
    manifest_path: Path, destination: Path, source_revision: str | None = None
) -> list[str]:
    manifest = read_manifest(manifest_path)
    entries = normalise_entries(manifest)
    destination = destination.expanduser().absolute()
    ensure_safe_destination(destination)
    destination.parent.mkdir(parents=True, exist_ok=True)
    ensure_safe_destination(destination)
    owned = old_files(destination)
    validate_conflicts(destination, entries, owned)
    validate_temporary_conflicts(destination, entries)
    staging = stage(entries, destination.parent)
    created_temporaries: list[Path] = []
    applied: list[tuple[dict[str, Any], Path]] = []
    backups: dict[str, Path] = {}
    try:
        backup_root = staging / ".rollback"
        for entry in entries:
            target = destination.joinpath(*entry["relative"].parts)
            if not target.exists():
                continue
            backup = backup_root.joinpath(*entry["relative"].parts)
            backup.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(target, backup)
            if file_hash(backup) != owned[entry["path"]]["sha256"]:
                raise ExportError(f"owned output changed during export: {target}")
            backups[entry["path"]] = backup

        destination.mkdir(mode=0o755, parents=True, exist_ok=True)
        for entry in entries:
            staged = staging.joinpath(*entry["relative"].parts)
            target = destination.joinpath(*entry["relative"].parts)
            target.parent.mkdir(mode=0o755, parents=True, exist_ok=True)
            temporary = output_temporary_path(target)
            try:
                with temporary.open("xb") as output, staged.open("rb") as source:
                    created_temporaries.append(temporary)
                    shutil.copyfileobj(source, output)
            except FileExistsError as error:
                raise ExportError(
                    f"temporary output already exists: {temporary}"
                ) from error
            temporary.chmod(int(entry["mode"], 8))
            os.replace(temporary, target)
            applied.append((entry, target))

        ownership = ownership_manifest(manifest, entries, source_revision)
        ownership_path = destination / OWNERSHIP_FILE
        ownership_temp = destination / OWNERSHIP_TEMP_FILE
        try:
            with ownership_temp.open("xb") as output:
                created_temporaries.append(ownership_temp)
                output.write(ownership)
        except FileExistsError as error:
            raise ExportError(
                f"temporary output already exists: {ownership_temp}"
            ) from error
        ownership_temp.chmod(stat.S_IRUSR | stat.S_IWUSR | stat.S_IRGRP | stat.S_IROTH)
        os.replace(ownership_temp, ownership_path)
    except Exception as error:
        rollback_errors = rollback_outputs(applied, backups)
        if rollback_errors:
            details = "; ".join(rollback_errors)
            raise ExportError(
                f"export failed and rollback was incomplete: {details}"
            ) from error
        if isinstance(error, ExportError):
            raise
        raise ExportError(f"cannot apply export: {error}") from error
    finally:
        for temporary in created_temporaries:
            with suppress(OSError):
                temporary.unlink(missing_ok=True)
        shutil.rmtree(staging, ignore_errors=True)

    desired = {entry["path"] for entry in entries}
    return sorted(set(owned) - desired)


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "destination",
        nargs="?",
        default="~/Zero/agentic-dots",
        help="fresh or previously owned destination (default: %(default)s)",
    )
    parser.add_argument(
        "--source-revision",
        required=True,
        help="exact source commit with a -dirty suffix when the worktree is dirty",
    )
    parser.add_argument(
        "--manifest",
        type=Path,
        default=(
            Path(os.environ["AGENTIC_DOTS_MANIFEST"])
            if "AGENTIC_DOTS_MANIFEST" in os.environ
            else None
        ),
        help=argparse.SUPPRESS,
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    if args.manifest is None:
        print("export-agentic-dots: AGENTIC_DOTS_MANIFEST is not set", file=sys.stderr)
        return 2
    try:
        stale = export(
            args.manifest, Path(args.destination), source_revision=args.source_revision
        )
    except ExportError as error:
        print(f"export-agentic-dots: {error}", file=sys.stderr)
        return 1
    print(f"Exported agentic-dots to {Path(args.destination).expanduser()}")
    if stale:
        print("Stale owned outputs were kept:")
        for path in stale:
            print(f"  {path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
