# repo-provision

Run this operator command **outside Fence**, after authenticating GitHub and installing the constrained `gh-api-safe` helper:

```console
nix run .#repo-provision
```

There are no arguments or activation hooks. The command provisions token-visible, nonarchived repositories from `wimpysworld`, `oval-tutu`, `linuxmatters`, `quickemu-project` and `noughtylinux`. Ordinary forks are included. It reads every API page and validates the full organisation response before acting on that organisation. A failed enumeration is an error, not an empty inventory. Token permissions can hide private repositories.

Destinations are `~/Development/<canonical-owner>/<repo>`, using API spelling. Only the repository named `.github` gets the checkout basename `_github`. For example, `wimpysworld/.github` becomes `~/Development/wimpysworld/_github`. Internal `.github` directories, workflows and repository metadata are not renamed.

Missing destinations are cloned over HTTPS. Existing plain repositories must have the expected root and a matching GitHub origin (standard HTTPS or SSH URL). Fetch updates only `refs/remotes/origin/*`, with no pruning, tags or submodule recursion. Configured fetch refspecs cannot update local branches. Fetch leaves the checked-out branch, index and working files alone. The command never pulls, resets, stashes, renames, deletes, changes remotes or migrates worktrees.

Output reports `CLONED`, `FETCHED`, `EMPTY` or `SKIP`. Symlinks at managed directories, non-repositories, worktrees, origin mismatches and case-insensitive path collisions are skipped. Both sides of a `.github`/`_github` inventory collision are skipped. Other repositories continue, with exit status 1 if anything fails. Invalid arguments return 2. Git error output and origin URLs are not printed, to avoid credential disclosure. Inspect a failed or partial clone manually.

The destination is fixed. `~/Zero` and other primary directories are not scanned or modified. `~/Development` and its owner directories must not be symlinks. Existing local repositories and Git configuration must be trusted. Do not run concurrently with another provisioner or filesystem changes. This is not a transaction or a defence against hostile Git configuration. There is no custom request timeout. Interrupt a stalled network operation and inspect its destination before retrying.

The Nix package runs ShellCheck and `test-repo-provision.sh`. Tests use mocked Git/GitHub commands and temporary homes, with no live clone or fetch. Home Manager integration and worktree policy are separate work.
