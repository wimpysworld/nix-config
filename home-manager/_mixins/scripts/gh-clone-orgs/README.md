# gh-clone-orgs

Run this operator command outside Fence after you authenticate GitHub and install `gh-api-safe`:

```console
gh-clone-orgs
```

Home Manager installs `gh-clone-orgs` on developer workstations. The command takes no arguments. It clones missing repositories and fetches existing checkouts from `wimpysworld`, `oval-tutu`, `linuxmatters`, `quickemu-project`, and `noughtylinux`. It includes forks and skips archived repositories. It reads every API page and validates the full organisation response before it acts on that organisation. A failed enumeration is an error, not an empty inventory.

Destinations are `~/Development/<canonical-owner>/<repo>` with the API owner spelling. If a repository name starts with `.`, the checkout basename replaces the leading `.` with `_`. It maps `.github` to `_github` and `.github-private` to `_github-private`. The names `.git`, `.worktrees`, and `_worktrees` are reserved and skipped. Internal `.github` directories and repository files do not change.

All Git network operations use HTTPS through `gh auth git-credential` with interactive prompts disabled. Missing destinations clone from `https://github.com/<owner>/<repo>.git`. Existing plain repositories must have the expected root and a matching GitHub `origin`. If `origin` uses `git@github.com:<owner>/<repo>(.git)` or `ssh://git@github.com/<owner>/<repo>(.git)` for the expected repository, `gh-clone-orgs` updates `origin` to `https://github.com/<owner>/<repo>.git` before it fetches. Fetch updates only `refs/remotes/origin/*`, with no pruning, tags, or submodule recursion. It leaves the checked-out branch, index, and working tree unchanged.

Output reports `CLONED`, `FETCHED`, `EMPTY`, or `SKIP`. The command skips symlinks at managed directories, non-repositories, worktrees, `origin` mismatches, and case-insensitive path collisions. If two repositories in an organisation map to the same destination (for example, `.github-private` and `_github-private`), the command skips both. Other repositories continue, and the command exits with status `1` if any repository or organisation fails. Invalid arguments return status `2`. Git error output and `origin` URLs are not printed.

The destination root is `~/Development`. The command does not scan or modify `~/Zero` or other directories. `~/Development` and its owner directories must not be symlinks. The Nix module runs ShellCheck on `gh-clone-orgs.sh` and `test-gh-clone-orgs.sh`, then runs the mock test suite in `postCheck`.
