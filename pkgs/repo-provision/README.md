# repo-provision: initial read-only planner

This operator command inventories token-visible GitHub repositories and reports local destination conflicts. It does not provision repositories yet. There is no apply option, clone, fetch, rename, reset, deletion, activation integration or local Git execution.

## Configuration

The root must already exist. Use an absolute path with no symlinks or parent traversal. Roots inside or containing `~/Zero` are rejected.

```json
{
  "root": "/absolute/path/to/Development",
  "owners": [
    {"login": "wimpysworld", "kind": "organization", "includeForks": false}
  ]
}
```

```console
repo-provision --config repositories.json
```

Install the constrained `gh-api-safe` helper separately and authenticate GitHub access before use. The command does not fall back to raw `gh api`. Organisation enumeration requires active membership. Personal enumeration requires the authenticated owner. Each owner needs an explicit fork policy.

Pagination continues to a short terminal page. `paginationComplete` confirms that traversal only, not visibility of every private repository or an atomic snapshot. Restricted tokens can silently omit repositories. An operator must check token permissions before using this inventory for future provisioning.

## Output and preservation

Output is JSON with `schemaVersion: 1`, `mode: "plan"` and `executable: false`. `actions` contains `candidate` for a missing destination or `preserve` for an excluded or conflicting destination. A candidate is informational, not permission to clone. `existing` lists local entries that remain untouched. `conflicts` records occupied destinations, symlinks and path collisions.

Exit status is zero for a completed inventory without conflicts, or one for conflicts and failures. A failed inventory returns `complete: false` and `actions: null`, never a partial list presented as success. `complete: true` means that inspection finished, not that the plan is executable or that token visibility is complete. Invalid command-line arguments return argparse exit status two.

The local scan reads directory names at exactly two levels, `<root>/<owner>/<repository>`. It does not open `.git`, run Git, resolve remote URLs or inspect checkout contents. Dirty, detached, divergent and multi-remote checkouts therefore remain uninspected and preserved. Existing destinations require later identity review, even when they look correct. `_worktrees` entries at either level are skipped. Internal metadata symlinks are not followed because repository contents are never scanned.

Only the repository named `.github` maps to local `_github`. GitHub identity remains `.github`. Internal `.github` folders and `.git` metadata remain untouched. `.github` and `_github` repositories under one owner conflict. Case-folded destination collisions also preserve all affected entries.

Archived repositories, excluded forks and `wimpysworld/nix-config` are preserved. The last identity is excluded for `~/Zero/nix-config`. No local identity adoption or duplicate-checkout reconciliation occurs in this stage. Local paths and private repository names in output can be sensitive. Save output only to private operator-owned files.

## Validation and staged delivery

The Nix package check phase runs `test_repo_provision.py`. Tests use temporary directories and mocked GitHub responses. They cover pagination failures, permissions, malformed inputs, path and mapping collisions, exclusions and preservation of untrusted checkout metadata. No live inventory, clone or fetch is part of validation.

Cloning and fetching are deferred. A later change needs stable identity adoption, saved-plan approval, descriptor-relative path checks, metadata validation, concurrency handling and detailed partial results. It also needs real Git integration tests on disposable macOS and Linux fixtures. This planner is a point-in-time report, not a filesystem transaction or an input to an apply command.

Home Manager integration, migrations and mandatory agent worktrees remain separate follow-up work.
