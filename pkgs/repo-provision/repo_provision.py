"""Read-only GitHub inventory planner. Clone, fetch and adoption are deferred."""

import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import unicodedata


class Blocked(Exception):
    pass


def api(endpoint):
    try:
        result = subprocess.run(
            ["gh-api-safe", endpoint], text=True, capture_output=True, check=True,
            env={**os.environ, "GH_PROMPT_DISABLED": "1"},
        )
        return json.loads(result.stdout)
    except (OSError, subprocess.SubprocessError, ValueError):
        # Arguments and stderr can contain credentials. Never include them.
        raise Blocked("GitHub request failed or returned invalid JSON") from None


def component(value):
    if not isinstance(value, str) or not re.fullmatch(r"[A-Za-z0-9_.-]+", value):
        raise Blocked("unsafe name")
    if value.casefold() in (".", "..", ".git", "_worktrees") or value.startswith("-"):
        raise Blocked("reserved name")
    return value


def identity(data):
    try:
        if not isinstance(data, dict) or not isinstance(data.get("full_name"), str):
            raise ValueError()
        owner, name = data["full_name"].split("/")
        component(owner)
        component(name)
        if not isinstance(data["node_id"], str) or not data["node_id"]:
            raise ValueError()
        if type(data["archived"]) is not bool or type(data["fork"]) is not bool:
            raise ValueError()
        return {key: data[key] for key in ("full_name", "node_id", "archived", "fork")}
    except (KeyError, ValueError, TypeError):
        raise Blocked("incomplete repository identity") from None


def folded(name):
    return unicodedata.normalize("NFC", name).casefold()


def safe_path(path):
    """Reject symlinks and ambiguous case at every existing path component."""
    if not path.is_absolute() or ".." in path.parts:
        raise Blocked("absolute non-traversing path required")
    current = Path(path.anchor)
    for part in path.parts[1:]:
        if current.exists():
            if not current.is_dir():
                raise Blocked("non-directory path component")
            matches = [p.name for p in current.iterdir() if folded(p.name) == folded(part)]
            if matches and matches != [part]:
                raise Blocked("case or Unicode path collision")
        current = current / part
        if current.is_symlink():
            raise Blocked("symlink path")
    return path


def inventory(owners):
    if not isinstance(owners, list) or not owners:
        raise Blocked("at least one explicit owner required")
    repos, evidence = [], []
    logins = set()
    for owner in owners:
        login = component(owner["login"])
        if folded(login) in logins:
            raise Blocked("duplicate owner")
        logins.add(folded(login))
        if owner["kind"] not in ("organization", "user") or type(owner["includeForks"]) is not bool:
            raise Blocked("owner kind and explicit fork policy required")
        viewer = api("user")
        if not isinstance(viewer, dict) or not isinstance(viewer.get("login"), str):
            raise Blocked("authentication unknown")
        if owner["kind"] == "user":
            if folded(viewer["login"]) != folded(login):
                raise Blocked("personal inventory requires the authenticated owner")
            endpoint = "user/repos?affiliation=owner&visibility=all"
        else:
            membership = api("user/memberships/orgs/" + login)
            if not isinstance(membership, dict) or membership.get("state") != "active":
                raise Blocked("organisation membership unknown")
            endpoint = "orgs/" + login + "/repos?type=all"
        seen, names = set(), set()
        for page in range(1, 10001):
            batch = api(f"{endpoint}&per_page=100&page={page}")
            if not isinstance(batch, list) or len(batch) > 100:
                raise Blocked("enumeration unknown")
            for item in batch:
                repo = identity(item)
                name = folded(repo["full_name"])
                if repo["node_id"] in seen or name in names:
                    raise Blocked("unstable pagination")
                seen.add(repo["node_id"])
                names.add(name)
                if folded(repo["full_name"].split("/")[0]) != folded(login):
                    raise Blocked("owner changed during enumeration")
                repos.append((repo, owner["includeForks"]))
            if len(batch) < 100:
                evidence.append({"owner": login, "pages": page, "paginationComplete": True,
                                 "visibility": "token-visible only"})
                break
        else:
            raise Blocked("pagination limit; inventory incomplete")
    return repos, evidence


def plan(config):
    root = safe_path(Path(config["root"]).expanduser())
    zero = Path.home() / "Zero"
    if root == zero or zero in root.parents or root in zero.parents:
        raise Blocked("roots inside or containing Zero are excluded")
    if not root.is_dir():
        raise Blocked("operator must create the inventory root first")
    repos, evidence = inventory(config["owners"])
    # Inspect names only. Never open repository metadata or invoke local Git.
    existing = []
    conflicts = []
    for parent in sorted(root.iterdir()):
        if parent.name == "_worktrees":
            continue
        if parent.is_symlink():
            conflicts.append({"path": str(parent), "reason": "symlink in inventory"})
        elif parent.is_dir():
            for path in sorted(parent.iterdir()):
                if path.name == "_worktrees":
                    continue
                existing.append({"path": str(path), "action": "preserve",
                                 "reason": "existing entry; identity not inspected"})
                if path.is_symlink():
                    conflicts.append({"path": str(path), "reason": "symlink in inventory"})
    actions = []
    destinations = {}
    for repo, forks in repos:
        owner, name = repo["full_name"].split("/")
        destination = root / owner / ("_github" if name.casefold() == ".github" else name)
        action = {"repository": repo, "path": str(destination), "action": "preserve"}
        key = folded(str(destination))
        destinations.setdefault(key, []).append(action)
        if folded(repo["full_name"]) == "wimpysworld/nix-config":
            action["reason"] = "explicit Zero identity exclusion"
        elif repo["archived"] or (repo["fork"] and not forks):
            action["reason"] = "archive or fork policy"
        else:
            try:
                safe_path(destination)
                if destination.exists():
                    action["reason"] = "occupied destination; identity not inspected"
                    conflicts.append({"path": str(destination), "reason": action["reason"]})
                else:
                    action.update(action="candidate", reason="missing destination; clone deferred")
            except (Blocked, OSError) as error:
                action["reason"] = str(error) if isinstance(error, Blocked) else "filesystem inspection failed"
                conflicts.append({"path": str(destination), "reason": action["reason"]})
        actions.append(action)
    for group in destinations.values():
        if len(group) > 1:
            for action in group:
                action.update(action="preserve", reason="destination collision")
            conflicts.append({"path": group[0]["path"], "reason": "destination collision"})
    return {"schemaVersion": 1, "mode": "plan", "enumeration": evidence,
            "root": str(root), "actions": actions, "existing": existing,
            "conflicts": conflicts, "complete": True, "executable": False}


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", required=True)
    args = parser.parse_args(argv)
    try:
        config = json.loads(Path(args.config).read_text())
        result = plan(config)
        print(json.dumps(result, indent=2))
        return 1 if result["conflicts"] else 0
    except (Blocked, OSError, ValueError, KeyError, TypeError) as error:
        reason = str(error) if isinstance(error, Blocked) else "configuration or filesystem error"
        print(json.dumps({"schemaVersion": 1, "complete": False, "mode": "blocked",
                          "executable": False, "error": reason, "actions": None}))
        return 1


if __name__ == "__main__":
    sys.exit(main())
