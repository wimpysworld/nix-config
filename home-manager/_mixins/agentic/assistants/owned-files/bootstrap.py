"""Recover verified ownership from the previous Home Manager generation."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import plistlib
import re
import shlex
import stat
import sys
import tempfile
from xml.parsers.expat import ExpatError


class Unsupported(ValueError):
    pass


def fingerprint(content):
    return {"kind": "file", "sha256": hashlib.sha256(content).hexdigest()}


def tokens(section):
    lexer = shlex.shlex(section, posix=True, punctuation_chars=";>")
    lexer.whitespace_split = True
    return list(lexer)


def printf_content(fmt, body):
    if fmt == "%s":
        return body.encode()
    if fmt in ("%s\\n", "%s\n"):
        return (body + "\n").encode()
    raise Unsupported("Unsupported printf format")


def parse_public(section):
    words = tokens(section)
    records = {}
    i = 0
    while i < len(words):
        if words[i:i + 2] in (["mkdir", "-p"], ["rm", "-rf"]):
            if i + 3 > len(words):
                raise Unsupported("Incomplete directory command")
            i += 3
        elif words[i:i + 2] == ["ln", "-sfn"] and i + 4 <= len(words):
            records[words[i + 3]] = {"kind": "symlink", "target": words[i + 2]}
            i += 4
        elif words[i] == "printf" and i + 5 <= len(words) and words[i + 3] == ">":
            records[words[i + 4]] = fingerprint(printf_content(words[i + 1], words[i + 2]))
            i += 5
        else:
            raise Unsupported("Unsupported public writer command")
    return records


def safe_secret_source(source, home, config_home=None, secret_root=None):
    path = Path(source)
    root = Path(secret_root) if secret_root else Path(config_home or Path(home) / ".config") / "sops-nix/secrets"
    return path.is_absolute() and ".." not in path.parts and path.is_relative_to(root) and path != root


def parse_secrets(section, home, config_home=None, secret_root=None):
    words = tokens(section)
    records = {}
    unavailable = False
    i = 0
    while i < len(words):
        if words[i:i + 3] != ["if", "[", "-r"] or words[i + 4:i + 7] != ["]", ";", "then"]:
            raise Unsupported("Unsupported secret condition")
        source = words[i + 3]
        if not safe_secret_source(source, home, config_home, secret_root):
            raise Unsupported("Secret source is outside the runtime secret directory")
        i += 7
        contents = {}
        while i < len(words) and words[i] != "else":
            if words[i:i + 2] == ["mkdir", "-p"] and i + 3 <= len(words):
                directory = words[i + 2]
                if directory.startswith("$(dirname ") and directory.endswith(")"):
                    arguments = shlex.split(directory[2:-1])
                    if len(arguments) != 2 or arguments[0] != "dirname":
                        raise Unsupported("Unsupported directory expression")
                i += 3
            elif words[i] == "printf" and i + 5 <= len(words) and words[i + 3] == ">":
                contents[words[i + 4]] = printf_content(words[i + 1], words[i + 2])
                i += 5
            elif words[i:i + 2] == ["cat", source] and i + 4 <= len(words) and words[i + 2] in (">", ">>"):
                target = words[i + 3]
                if words[i + 2] == ">>" and target not in contents:
                    raise Unsupported("Secret append has no literal prefix")
                try:
                    body = Path(source).read_bytes()
                except OSError:
                    body = None
                    unavailable = True
                prefix = contents.get(target, b"") if words[i + 2] == ">>" else b""
                contents[target] = prefix + body if body is not None else None
                i += 4
            else:
                raise Unsupported("Unsupported secret writer command")
        if words[i:i + 2] != ["else", "echo"] or words[i + 3:i + 6] != [">", "&2", "fi"]:
            raise Unsupported("Unsupported secret fallback")
        i += 6
        records.update({path: fingerprint(body) for path, body in contents.items() if body is not None})
    if unavailable:
        print("Owned-file bootstrap: previous secret bodies are unavailable, leaving unverified copies unchanged.", file=sys.stderr)
    return records


def sections(script):
    marker = re.compile(r'^_iNote "Activating %s" "([^"\n]+)"\n', re.MULTILINE)
    matches = list(marker.finditer(script))
    return {
        match.group(1): script[match.end():matches[index + 1].start() if index + 1 < len(matches) else len(script)]
        for index, match in enumerate(matches)
    }


def allowed(path, roots):
    candidate = Path(path)
    return candidate.is_absolute() and ".." not in candidate.parts and any(
        candidate != root and candidate.is_relative_to(root) for root in map(Path, roots)
    )


def assistant_path(path, roots, codex_only=False):
    if not allowed(path, roots):
        return False
    for root in map(Path, roots):
        candidate = Path(path)
        if not candidate.is_relative_to(root):
            continue
        parts = candidate.relative_to(root).parts
        codex = root.name in ("codex", ".codex")
        if codex_only and not codex:
            continue
        if codex and parts == ("AGENTS.md",):
            return True
        if len(parts) >= 2 and parts[0] in ("agents", "commands", "prompts", "skills"):
            return True
    return False


def verified_records(expected, roots):
    verified = {}
    for name, record in expected.items():
        if not allowed(name, roots) or not isinstance(record, dict):
            continue
        path = Path(name)
        if any(parent.is_symlink() for parent in path.parents):
            continue
        try:
            info = path.lstat()
            if record.get("kind") == "symlink" and isinstance(record.get("target"), str):
                matches = stat.S_ISLNK(info.st_mode) and os.readlink(path) == record["target"]
            elif record.get("kind") == "file" and re.fullmatch(r"[0-9a-f]{64}", str(record.get("sha256", ""))):
                matches = stat.S_ISREG(info.st_mode) and fingerprint(path.read_bytes()) == record
            else:
                continue
            if matches:
                verified[name] = record
        except OSError:
            continue
    return verified


def store_path(value):
    path = Path(value)
    return path.is_absolute() and ".." not in path.parts and path.is_relative_to("/nix/store")


def immutable_text(path):
    path = Path(path).resolve()
    if not store_path(str(path)):
        raise Unsupported("Previous generation reference is outside the Nix store")
    return path.read_text()


def darwin_sops_script(generation):
    plist = generation / "LaunchAgents/org.nix-community.home.sops-nix.plist"
    if not plist.exists():
        return None
    try:
        definition = plistlib.loads(immutable_text(plist).encode())
    except (ValueError, ExpatError, plistlib.InvalidFileException) as error:
        raise Unsupported("Unsupported previous sops launchd plist") from error
    if not isinstance(definition, dict):
        raise Unsupported("Unsupported previous sops launchd plist")
    arguments = definition.get("ProgramArguments")
    if not isinstance(arguments, list) or not all(isinstance(argument, str) for argument in arguments):
        raise Unsupported("Unsupported previous sops launchd arguments")
    if len(arguments) == 3 and arguments[:2] == ["/bin/sh", "-c"]:
        command = shlex.split(arguments[2])
        if len(command) != 5 or command[:4] != ["/bin/wait4path", "/nix/store", "&&", "exec"]:
            raise Unsupported("Unsupported previous sops launchd wait command")
        script = command[4]
    elif len(arguments) == 1 and store_path(arguments[0]) and arguments[0].endswith("/bin/sops-nix"):
        command = tokens(immutable_text(arguments[0]))
        if len(command) != 2 or command[0] != "exec":
            raise Unsupported("Unsupported previous sops launchd wrapper")
        script = command[1]
    else:
        raise Unsupported("Unsupported previous sops launchd command")
    if not store_path(script):
        raise Unsupported("Previous sops launchd script is outside the Nix store")
    return script


def old_sops_manifest(generation, config_relative=Path(".config")):
    service = generation / "home-files" / config_relative / "systemd/user/sops-nix.service"
    if service.exists():
        starts = re.findall(r"^ExecStart=(.+)$", immutable_text(service), re.MULTILINE)
        if len(starts) != 1:
            raise Unsupported("Unsupported previous sops service")
        command = shlex.split(starts[0])
        if len(command) != 1 or not store_path(command[0]):
            raise Unsupported("Unsupported previous sops service command")
        script = command[0]
    else:
        script = darwin_sops_script(generation)
        if script is None:
            return {}
    words = tokens(immutable_text(script))
    if len(words) != 3 or not words[0].endswith("/bin/sops-install-secrets") or words[1] != "-ignore-passwd" or not store_path(words[2]):
        raise Unsupported("Unsupported previous sops installation command")
    manifest = json.loads(immutable_text(words[2]))
    if not isinstance(manifest, dict):
        raise Unsupported("Unsupported previous sops manifest")
    return manifest


def old_secret_links(generation, roots, config_relative=Path(".config"), manifest=None):
    if manifest is None:
        manifest = old_sops_manifest(generation, config_relative)
    if not manifest:
        return {}
    link_root = manifest.get("symlinkPath", "")
    if not Path(link_root).is_absolute():
        raise Unsupported("Unsupported previous runtime secret directory")
    records = {}
    for secret in manifest.get("secrets", []):
        path, name = secret.get("path", ""), secret.get("name", "")
        if assistant_path(path, roots) and name and not Path(name).is_absolute() and ".." not in Path(name).parts:
            records[path] = {"kind": "symlink", "target": str(Path(link_root) / name)}
    for template in manifest.get("templates", []):
        path, name = template.get("path", ""), template.get("name", "")
        if assistant_path(path, roots) and name and not Path(name).is_absolute() and ".." not in Path(name).parts:
            records[path] = {"kind": "symlink", "target": str(Path(link_root) / "rendered" / name)}
    return records


def capture(spec, old_generation):
    if (Path(spec["stateDir"]) / "manifest.json").exists() or not old_generation:
        return {}
    generation = Path(old_generation).resolve()
    if not store_path(str(generation)) or not (generation / "activate").is_file():
        print("Owned-file bootstrap: no immutable previous generation, leaving existing files unchanged.", file=sys.stderr)
        return {}
    script_sections = sections(immutable_text(generation / "activate"))
    expected = {}
    manifest = {}
    try:
        config_relative = Path(spec.get("configHome", str(Path(spec["home"]) / ".config"))).relative_to(spec["home"])
        manifest = old_sops_manifest(generation, config_relative)
        expected.update(old_secret_links(generation, spec["roots"], config_relative, manifest))
    except (OSError, Unsupported, ValueError, KeyError, TypeError):
        print("Owned-file bootstrap: cannot verify previous secret links, leaving them unchanged.", file=sys.stderr)
    for name, parser in (("codexFiles", parse_public),
                         ("codexSecretFiles", lambda text: parse_secrets(text, spec["home"], spec.get("configHome"), manifest.get("symlinkPath")))):
        try:
            expected.update({path: record for path, record in parser(script_sections.get(name, "")).items()
                             if assistant_path(path, spec["roots"], codex_only=True)})
        except (Unsupported, ValueError, IndexError):
            print(f"Owned-file bootstrap: unsupported previous {name} writer, leaving its files unchanged.", file=sys.stderr)
    return verified_records(expected, spec["roots"])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("spec")
    parser.add_argument("--old-generation", default="")
    parser.add_argument("--output", required=True)
    args = parser.parse_args()
    spec = json.loads(Path(args.spec).read_text())
    destination = Path(args.output)
    if destination != Path(spec["stateDir"]) / "bootstrap.json":
        raise ValueError("Bootstrap output must be bootstrap.json in stateDir")
    if any(parent.is_symlink() for parent in (destination.parent, *destination.parent.parents)):
        raise ValueError("Bootstrap state directory must not contain symlinks")
    records = {}
    if destination.exists() and not (Path(spec["stateDir"]) / "manifest.json").exists():
        info = destination.lstat()
        if not stat.S_ISREG(info.st_mode) or info.st_uid != os.getuid() or stat.S_IMODE(info.st_mode) != 0o600:
            raise ValueError("Existing bootstrap must be a private regular file owned by the current user")
        previous = json.loads(destination.read_text())
        if not isinstance(previous, dict) or previous.get("version") != 1 or not isinstance(previous.get("files"), dict):
            raise ValueError("Invalid existing bootstrap manifest")
        records.update(verified_records(previous["files"], spec["roots"]))
    records.update(capture(spec, args.old_generation))
    result = {"version": 1, "files": records, "directories": []}
    destination.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    os.chmod(destination.parent, 0o700)
    fd, temporary = tempfile.mkstemp(prefix=".bootstrap-", dir=destination.parent)
    try:
        with os.fdopen(fd, "w") as handle:
            json.dump(result, handle, sort_keys=True)
            handle.write("\n")
        os.replace(temporary, destination)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


if __name__ == "__main__":
    main()
