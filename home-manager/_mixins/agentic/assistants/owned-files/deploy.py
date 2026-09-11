#!/usr/bin/env python3
"""Deploy explicit generated files without replacing unowned content."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import stat
import sys
import tempfile


class Conflict(Exception):
    pass


def absolute(value):
    path = Path(value)
    if not path.is_absolute() or ".." in path.parts:
        raise Conflict(f"Expected an absolute path without '..': {path}")
    return path


def parents_safe(path):
    for parent in reversed(path.parents):
        try:
            info = parent.lstat()
        except FileNotFoundError:
            continue
        if not stat.S_ISDIR(info.st_mode):
            raise Conflict(f"Destination parent is not a real directory: {parent}")


def allowed(path, roots):
    if not any(path != root and path.is_relative_to(root) for root in roots):
        raise Conflict(f"Destination is outside the allowed roots: {path}")
    parents_safe(path)
    return path


def fingerprint(path):
    try:
        info = path.lstat()
    except FileNotFoundError:
        return None
    if stat.S_ISLNK(info.st_mode):
        return {"kind": "symlink", "target": os.readlink(path)}
    if stat.S_ISREG(info.st_mode):
        return {"kind": "file", "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}
    return {"kind": "other"}


def load_manifest(path):
    if not path.exists() and not path.is_symlink():
        return {"version": 1, "files": {}, "directories": []}
    if not stat.S_ISREG(path.lstat().st_mode):
        raise Conflict(f"Manifest is not a regular file: {path}")
    data = json.loads(path.read_text())
    if data.get("version") != 1 or not isinstance(data.get("files"), dict):
        raise Conflict("Unsupported ownership manifest")
    directories = data.get("directories", [])
    if not isinstance(directories, list) or any(not isinstance(path, str) for path in directories):
        raise Conflict("Invalid owned directory list")
    for value in data["files"].values():
        if not isinstance(value, dict) or value.get("kind") not in ("file", "symlink"):
            raise Conflict("Invalid ownership fingerprint")
        if value["kind"] == "file" and (
            not isinstance(value.get("sha256"), str)
            or len(value["sha256"]) != 64
            or any(c not in "0123456789abcdef" for c in value["sha256"])
        ):
            raise Conflict("Invalid file fingerprint")
        if value["kind"] == "symlink" and not isinstance(value.get("target"), str):
            raise Conflict("Invalid symlink fingerprint")
    return data


def snapshot(path):
    current = fingerprint(path)
    if current is None:
        return None
    if current["kind"] == "symlink":
        return ("symlink", current["target"], None)
    if current["kind"] != "file":
        raise Conflict(f"Cannot replace a non-file destination: {path}")
    return ("file", path.read_bytes(), stat.S_IMODE(path.stat().st_mode))


def replace(path, value):
    parents_safe(path)
    if value is None:
        path.unlink(missing_ok=True)
        return
    kind, content, mode = value
    descriptor, temporary = tempfile.mkstemp(prefix=".agent-owned-", dir=path.parent)
    temporary = Path(temporary)
    try:
        if kind == "file":
            with os.fdopen(descriptor, "wb") as output:
                descriptor = None
                output.write(content)
                output.flush()
                os.fchmod(output.fileno(), mode)
                os.fsync(output.fileno())
        else:
            os.close(descriptor)
            descriptor = None
            temporary.unlink()
            temporary.symlink_to(content)
        os.replace(temporary, path)
    finally:
        if descriptor is not None:
            os.close(descriptor)
        temporary.unlink(missing_ok=True)


def make_parents(path, created):
    parents_safe(path)
    missing = []
    parent = path.parent
    while not parent.exists():
        missing.append(parent)
        parent = parent.parent
    for parent in reversed(missing):
        parent.mkdir(mode=0o700)
        created.append(parent)


def deploy(spec, dry_run=False, bootstrap_manifest=None):
    if spec.get("version") != 1:
        raise Conflict("Unsupported deployment specification")
    roots = [absolute(root) for root in spec["roots"]]
    state = absolute(spec["stateDir"])
    parents_safe(state / "manifest.json")
    if any(state == root or state.is_relative_to(root) for root in roots):
        raise Conflict("Ownership state must be outside client roots")
    if state.exists() and (
        state.stat().st_uid != os.getuid() or stat.S_IMODE(state.stat().st_mode) & 0o077
    ):
        raise Conflict(f"Ownership state is not private: {state}")
    manifest_path = state / "manifest.json"
    manifest = load_manifest(manifest_path)
    old = {allowed(absolute(path), roots): value for path, value in manifest["files"].items()}
    owned_directories = {
        allowed(absolute(path), roots) for path in manifest.get("directories", [])
    }
    if bootstrap_manifest:
        bootstrap = load_manifest(absolute(bootstrap_manifest))
        for path, value in bootstrap["files"].items():
            path = allowed(absolute(path), roots)
            if path not in old:
                old[path] = value
        owned_directories.update(
            allowed(absolute(path), roots)
            for path in bootstrap.get("directories", [])
            if absolute(path) not in roots
        )
    desired = {}
    expected = {}
    for entry in spec["files"]:
        path = allowed(absolute(entry["path"]), roots)
        if path in desired:
            raise Conflict(f"Duplicate destination: {path}")
        source = absolute(entry["source"])
        kind = entry["kind"]
        if kind == "file":
            if not source.is_file():
                raise Conflict(f"Required source is not a readable file: {source}")
            content = entry.get("prefix", "").encode() + source.read_bytes()
            mode = int(entry.get("mode", "0600"), 8)
            if mode not in (0o600, 0o644, 0o700, 0o755):
                raise Conflict(f"Unsupported file mode for {path}")
            desired[path] = (kind, content, mode)
            expected[path] = {"kind": kind, "sha256": hashlib.sha256(content).hexdigest()}
        elif kind == "symlink":
            if source.is_file():
                source.read_bytes()
            elif source.is_dir():
                with os.scandir(source) as entries:
                    list(entries)
            else:
                raise Conflict(f"Required symlink source is unavailable: {source}")
            desired[path] = (kind, str(source), None)
            expected[path] = {"kind": kind, "target": str(source)}
        else:
            raise Conflict(f"Unsupported destination kind: {kind}")
        current = fingerprint(path)
        if current is not None and current != old.get(path):
            proven = False
            for candidate in entry.get("bootstrapSources", []):
                candidate = absolute(candidate)
                if kind == "symlink":
                    proven |= current == {"kind": "symlink", "target": str(candidate)}
                elif candidate.is_file():
                    proven |= current == fingerprint(candidate)
            if not proven:
                raise Conflict(f"Preserving an unowned or modified destination: {path}")
    for path in desired:
        if any(parent in desired for parent in path.parents):
            raise Conflict(f"Destination overlaps another generated file: {path}")
    changes = dict(desired)
    for path, recorded in old.items():
        if path not in desired:
            current = fingerprint(path)
            if current == recorded:
                changes[path] = None
            elif current is not None:
                print(f"Preserving modified former output: {path}", file=sys.stderr)
    retired = set(manifest.get("retired", []))
    for name in spec.get("retire", []):
        path = allowed(absolute(name), roots)
        if path.name != "traya.md" or path.parts[-4:] != (".pi", "agent", "agents", "traya.md"):
            raise Conflict(f"Unapproved legacy retirement: {path}")
        if str(path) in retired:
            continue
        if path in desired:
            raise Conflict(f"Retirement overlaps a desired destination: {path}")
        current = fingerprint(path)
        if current is not None and current["kind"] != "file":
            print(f"Preserving non-regular legacy path: {path}", file=sys.stderr)
        elif current is not None:
            changes[path] = None
        retired.add(str(path))
    before = {path: snapshot(path) for path in changes}
    original_fingerprints = {path: fingerprint(path) for path in changes}
    if dry_run:
        print(f"Would deploy {len(desired)} files and retire {sum(v is None for v in changes.values())} files")
        return
    created = []
    applied = []
    removed_directories = []
    try:
        make_parents(manifest_path, created)
        for path, value in changes.items():
            if value is not None:
                make_parents(path, created)
            parents_safe(path)
            if fingerprint(path) != original_fingerprints[path]:
                raise Conflict(f"Destination changed during deployment: {path}")
            replace(path, value)
            applied.append(path)
        owned_directories.update(
            path for path in created if any(path != root and path.is_relative_to(root) for root in roots)
        )
        for directory in sorted(owned_directories, key=lambda path: len(path.parts), reverse=True):
            parents_safe(directory)
            if directory.is_symlink():
                continue
            try:
                mode = stat.S_IMODE(directory.stat().st_mode)
                directory.rmdir()
                removed_directories.append((directory, mode))
            except (FileNotFoundError, OSError):
                pass
        remaining_directories = [str(path) for path in owned_directories if path.is_dir() and not path.is_symlink()]
        result = {
            "version": 1,
            "files": {str(path): value for path, value in expected.items()},
            "directories": sorted(remaining_directories),
            "retired": sorted(retired),
        }
        replace(manifest_path, ("file", (json.dumps(result, indent=2) + "\n").encode(), 0o600))
    except BaseException:
        failures = []
        for directory, mode in reversed(removed_directories):
            try:
                parents_safe(directory)
                directory.mkdir(mode=mode)
                directory.chmod(mode)
            except (OSError, Conflict):
                failures.append(str(directory))
        for path in reversed(applied):
            try:
                make_parents(path, created)
                replace(path, before[path])
            except (OSError, Conflict):
                failures.append(str(path))
        for directory in reversed(created):
            try:
                directory.rmdir()
            except OSError:
                pass
        if failures:
            raise Conflict("Rollback failed for: " + ", ".join(failures)) from None
        raise
    if bootstrap_manifest:
        bootstrap_path = absolute(bootstrap_manifest)
        if bootstrap_path == state / "bootstrap.json" and not bootstrap_path.is_symlink():
            bootstrap_path.unlink(missing_ok=True)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("spec")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--bootstrap-manifest")
    args = parser.parse_args(argv)
    try:
        spec = json.loads(Path(args.spec).read_text())
        deploy(spec, args.dry_run or bool(os.environ.get("DRY_RUN_CMD")), args.bootstrap_manifest)
    except (OSError, ValueError, KeyError, TypeError, Conflict) as error:
        print(f"Agent file deployment failed: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
