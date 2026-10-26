# gh-token-push

Copy the local GitHub CLI token for github.com to servers, then refresh their `gh` login:

```bash
gh-token-push malak revan
gh-token-push --all
```

`--all` targets every host with `kind = "server"` in `lib/registry-systems.toml`. The list is built when Nix evaluates the module.

The token goes to each host only through the standard input of `ssh`. It never appears in argv, output, or logs. On each host, the script runs `gh auth login --with-token --insecure-storage`, checks `gh auth status`, and runs `gh-credential-sync`. Hosts are processed one at a time, with one status line each. The exit status is non-zero when any host fails.

A `ghu_` token or an unknown token type causes a warning, because the copy can expire. All host names are checked before the script reads the token.

Hosts with the `cg` tag do not get this script, because a work policy forbids SSH from them.
