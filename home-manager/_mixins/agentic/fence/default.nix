{
  config,
  inputs,
  lib,
  noughtyLib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;
  inherit (config.home) homeDirectory profileDirectory;
  fencePackage = import ./package.nix { inherit inputs pkgs; };

  fenceConfig = {
    allowPty = true;
    network = {
      allowedDomains = [ "*" ];
      deniedDomains = [ ];
      allowLocalBinding = true;
      allowLocalOutbound = true;
    };
    devices.mode = "minimal";
    filesystem = {
      defaultDenyRead = false;
      allowRead = [
        "/nix"
        "/nix/**"
        "${profileDirectory}"
        "${profileDirectory}/**"
        "${config.xdg.configHome}/sops-nix"
        "${config.xdg.configHome}/sops-nix/**"
      ];
      allowWrite = [
        "."
        "${homeDirectory}/Chainguard"
        "${homeDirectory}/Chainguard/**"
        "${homeDirectory}/Development"
        "${homeDirectory}/Development/**"
        "${homeDirectory}/Volatile"
        "${homeDirectory}/Volatile/**"
        "${homeDirectory}/Zero"
        "${homeDirectory}/Zero/**"

        # Temp files
        "/tmp/**"

        # Claude Code
        "${config.xdg.configHome}/ccstatusline"
        "~/.claude*"
        "~/.claude/**"

        # Codex
        "~/.codex/**"

        # Copilot
        "~/.copilot/**"

        # OpenCode
        "${config.xdg.configHome}/opencode"
        "~/.opencode/**"

        # Pi
        "${homeDirectory}/.pi/**"
        "${homeDirectory}/.pi-lens"
        "${homeDirectory}/.pi-lens/**"

        # Package manager caches
        "~/.npm/_cacache"
        "~/.npm/_npx"
        "~/.bun/**"

        # Cargo cache (Rust, used by Codex)
        "~/.cargo/registry/**"
        "~/.cargo/git/**"
        "~/.cargo/.package-cache"

        # Shell completion cache
        "~/.zcompdump*"

        # XDG directories
        "${config.xdg.cacheHome}/**"
        "${config.xdg.dataHome}/**"
        "${config.xdg.stateHome}/**"
        "~/.local/go"
        "~/.local/go/**"
      ];

      denyRead = [
        "/etc/passwd"
        "/etc/shadow"

        # SSH private keys and config
        "~/.ssh/**"

        # GPG keys
        "~/.gnupg/**"

        # Cloud provider credentials
        "~/.aws/**"
        "~/.azure/**"
        "${config.xdg.configHome}/gcloud/**"
        "~/.kube/**"

        # Docker config (may contain registry auth)
        "~/.docker/**"

        # Package manager auth tokens
        "~/.pypirc"
        "~/.netrc"
        "~/.git-credentials"
        "~/.cargo/credentials"
        "~/.cargo/credentials.toml"

        # SOPS: user age key, host age key, and runtime decrypted secrets.
        "${config.xdg.configHome}/sops/**"
        "/var/lib/private/sops/**"

        # History
        "${homeDirectory}/.bash_history"
        "${homeDirectory}/.zsh_history"
        "${homeDirectory}/.fish_history"
        "${config.xdg.dataHome}/fish/fish_history"
      ];
    };
    command = {
      useDefaults = true;
      runtimeExecPolicy = "argv";
      acceptSharedBinaryCannotRuntimeDeny = [
        # Nixpkgs coreutils is a multicall binary. Runtime-masking any of
        # these would also mask `env`, breaking common shebangs.
        "chroot"
        "dd"
        "shred"
        "truncate"
      ];
      allow = [
        "git reset --soft"
        "git reset --mixed"
        "git rebase --abort"
        "git rebase --continue"
        # git config: read-shaped subcommands and flags carved out
        # of the family-wide `git config` deny below. The modern
        # subcommand reads (`get`, `get-all`, `get-regexp`,
        # `get-urlmatch`, `list`) are matched on the first token
        # after `config`, so any destination flag (`--global`,
        # `--system`, `--local`, `--file`, `--worktree`, `--blob`)
        # trails the read token and the rule still fires. The
        # legacy flag reads (`--get`, `--get-all`, `--get-regexp`,
        # `--get-urlmatch`, `--get-color`, `--get-colorbool`,
        # `--list`, `-l`) only match when the read flag is the
        # first token after `config`; a destination flag placed
        # before the read flag (e.g. `git config --global --get
        # user.email`) is not carved out and falls through to the
        # family-wide deny.
        "git config get"
        "git config get-all"
        "git config get-regexp"
        "git config get-urlmatch"
        "git config list"
        "git config --get"
        "git config --get-all"
        "git config --get-regexp"
        "git config --get-urlmatch"
        "git config --get-color"
        "git config --get-colorbool"
        "git config --list"
        "git config -l"
        # OpenCode probes the working tree at startup with
        # `git config --bool core.bare`, which reads the boolean
        # interpretation of `core.bare`. The `--bool` flag is a
        # type filter rather than a read verb, so it does not match
        # any of the carve-outs above and falls through to the
        # family-wide `git config` deny. Allow this argv prefix so
        # `opencode-fenced` can start. Fence allow rules are
        # token-prefix matches, so additional trailing arguments are
        # also permitted, including boolean writes if git accepts later
        # scope flags. This is the narrowest practical carve-out under
        # the current argv-prefix matcher; the family-wide `git config`
        # deny remains below.
        "git config --bool core.bare"
        # gh auth: identity inspection and credential rotation are
        # non-destructive under Fence. Claude Code shells out to
        # `gh auth token`, so token disclosure is explicitly allowed
        # while git-config rewriting and stdin-driven token injection
        # stay denied below. `gh auth login` is deliberately
        # not allow-listed here because Fence's allow rules take
        # precedence over denies, so a bare `gh auth login` allow
        # would shadow the longer-prefix `gh auth login --with-token`
        # deny. The bare interactive form remains permitted by default
        # because nothing else denies it.
        "gh auth logout"
        "gh auth refresh"
        "gh auth status"
        "gh auth switch"
        "gh auth token"
        # Literal-path `gh api` allows that pair with the family-wide
        # `gh api` deny below. These three endpoints are read-only,
        # body-free, and method-fixed, so allowing them directly avoids
        # forcing every invocation through `gh-api-safe`. All other
        # read-shaped requests must go via the wrapper.
        "gh api rate_limit"
        "gh api meta"
        "gh api octocat"
        # gh extension discovery reads. These pair with the family-wide
        # `gh extension`, `gh extensions`, and `gh ext` denies below so
        # the agent can search and browse without being able to install,
        # remove, exec, or upgrade extensions.
        "gh extension list"
        "gh extension search"
        "gh extension browse"
        "gh extensions list"
        "gh extensions search"
        "gh extensions browse"
        "gh ext list"
        "gh ext search"
        "gh ext browse"
        # gh release reads. These pair with the family-wide `gh release`
        # deny below so the agent can inspect and download published
        # artefacts without being able to publish, edit, or delete them.
        "gh release list"
        "gh release view"
        "gh release download"
        # gh project reads. These pair with the family-wide `gh project`
        # deny below so the agent can inspect project boards without
        # being able to mutate items, fields, or project state.
        "gh project view"
        "gh project list"
        "gh project field-list"
        "gh project item-list"
        # Discovery reads under otherwise family-wide-denied gh
        # namespaces. The principle is: list-like subcommands stay
        # available so the agent can inspect state, while any mutation
        # remains denied by the family-wide entry below. Name and
        # fingerprint disclosure under identity-material and
        # CI-configuration namespaces is accepted as the cost of
        # discovery; secret values are not exposed because the only
        # read subcommand carved out is the name-listing one.
        "gh codespace list"
        "gh codespace view"
        "gh cs list"
        "gh cs view"
        "gh gpg-key list"
        "gh ssh-key list"
        "gh label list"
        "gh label view"
        "gh secret list"
        "gh variable list"
        "gh variable get"
        "gh repo deploy-key list"
      ];
      deny = [
        "just switch"
        "just switch-home"
        "just switch-host"
        "git push"
        "git reset"
        "git clean"
        "git rebase"
        # git config: family-wide deny to protect the Nix-managed
        # git configuration and stop the agent rewriting
        # credential helpers, `safe.directory` entries, aliases,
        # remote URLs, or any other config surface. Read-shaped
        # subcommands and flags are carved out in the allow block
        # above; every write shape (bare positional assignment,
        # `--add`, `--unset`, `--unset-all`, `--replace-all`,
        # `--rename-section`, `--remove-section`, `--edit`, the
        # modern `set`/`unset`/`rename-section`/`remove-section`
        # subcommands) and every uncarved destination flag
        # (`--file`, `--blob`, etc.) falls through to this deny.
        "git config"
        "home-manager switch"
        "home-manager switch-generation"
        "nixos-rebuild switch"
        "nixos-rebuild boot"
        "darwin-rebuild switch"
        "nh home switch"
        "nh os switch"
        "nh os boot"
        "nh darwin switch"
        "nix run nixpkgs#home-manager"
        "nix run home-manager"
        "nix run github:nix-community/home-manager"
        "nix run nixpkgs#nixos-rebuild"
        "nix run nixos-rebuild"
        "nix run nixpkgs#darwin-rebuild"
        "nix run nix-darwin"
        "nix run github:lnl7/nix-darwin"
        "nix-collect-garbage"
        "nix store gc"
        "nix store delete"
        "nix upgrade-nix"
        "nix-store --gc"
        "nix-store --delete"
        "systemctl poweroff"
        "systemctl reboot"
        "systemctl halt"
        "systemctl suspend"
        "systemctl hibernate"
        "systemctl rescue"
        "systemctl emergency"
        "docker rm"
        "docker rmi"
        "docker system prune"
        "docker volume prune"
        "docker container prune"
        "docker image prune"
        "docker network prune"
        "docker volume rm"
        "docker network rm"
        "sudo"
        "doas"
        "pkexec"
        "xargs sudo"
        "xargs doas"
        "xargs pkexec"
        "nohup sudo"
        "nohup doas"
        "nohup pkexec"
        "env sudo"
        "env doas"
        "env pkexec"
        "setsid sudo"
        "setsid doas"
        "setsid pkexec"
        "dd"
        "shred"
        "wipe"
        "srm"
        "truncate"
        "npm publish"
        "pnpm publish"
        "yarn publish"
        "cargo publish"
        "twine upload"
        "gem push"
        # Raw gh api is the escape hatch. Reads must go via
        # gh-api-safe; the literal allow entries above are the only
        # bypass.
        "gh api"
        # gh alias: shell aliasing is a configuration surface.
        "gh alias delete"
        "gh alias import"
        "gh alias set"
        # gh auth: the git-config-rewriting subcommand is denied to
        # protect the Nix-managed git configuration. `gh auth token`
        # is allow-listed above because Claude Code requires it.
        # `gh auth login --with-token` accepts a token on stdin (or
        # via `--with-token=PATH`) and silently rebinds the active
        # credential, so both the positional and `=`-presence forms
        # are denied.
        "gh auth setup-git"
        "gh auth login --with-token"
        "gh auth login --with-token="
        # gh cache: deletion mutates CI cache state.
        "gh cache delete"
        # gh codespace: creates and operates remote infrastructure.
        # Family-wide deny covers both the canonical name and the `cs`
        # alias, including `logs`, which can stream secret values
        # printed by codespace processes. Discovery reads (`list`,
        # `view`) are carved out above.
        "gh codespace"
        "gh cs"
        # gh config: the entire CLI-configuration namespace, including
        # reads. `gh config get oauth_token --host github.com` can
        # disclose the OAuth token stored in `~/.config/gh/hosts.yml`,
        # so no read carve-outs are offered here even though the rest
        # of the gh policy applies the list-like-read principle.
        "gh config"
        # gh extension: family-wide deny. Discovery reads are carved
        # out in the allow block above.
        "gh extension"
        "gh extensions"
        "gh ext"
        # gh gist: creation, edit, and deletion are denied. Gists are
        # a public-by-default exfiltration channel: the agent can
        # publish arbitrary file contents in a single command and the
        # action is invisible to repo-level review. This reverses the
        # earlier "git-tracked, safe" decision on batfink's
        # exfil-channel finding. Reads (`view`, `list`, `clone`) stay
        # allow-by-default.
        "gh gist create"
        "gh gist edit"
        "gh gist delete"
        # gh gpg-key and gh ssh-key: identity material. The `list`
        # subcommand is carved out above so the agent can enumerate
        # registered keys; addition and removal remain denied.
        "gh gpg-key"
        "gh ssh-key"
        # gh issue: destructive and moderation-config subcommands.
        "gh issue delete"
        "gh issue lock"
        "gh issue unlock"
        "gh issue transfer"
        "gh issue pin"
        "gh issue unpin"
        # gh label: repo-level configuration of triage taxonomy.
        # Family-wide deny so per-project label management stays under
        # separate tooling. `gh label list` is carved out above for
        # discovery.
        "gh label"
        # gh pr: merges, moderation, and self-approval. `update-branch`
        # is intentionally not denied so the agent can resolve
        # out-of-date PR branches. Both the positional `--approve` and
        # `--approve=` forms are denied so the agent cannot rubber-stamp
        # its own pull requests; `--comment` and `--request-changes`
        # remain available for review feedback.
        "gh pr merge"
        "gh pr lock"
        "gh pr unlock"
        "gh pr review --approve"
        "gh pr review --approve="
        # gh project: family-wide deny. Reads are carved out above.
        "gh project"
        # gh release: family-wide deny. Reads are carved out above.
        "gh release"
        # gh repo: enumerated mutations. Reads (view, list, clone, fork)
        # remain allow-by-default. `gh repo deploy-key` is family-wide
        # denied with `gh repo deploy-key list` carved out above.
        "gh repo create"
        "gh repo new"
        "gh repo archive"
        "gh repo unarchive"
        "gh repo autolink create"
        "gh repo autolink new"
        "gh repo autolink delete"
        "gh repo delete"
        "gh repo deploy-key"
        "gh repo edit"
        "gh repo rename"
        "gh repo set-default"
        "gh repo sync"
        # gh run: only deletion is denied; rerun and cancel remain
        # available as CI-debugging affordances.
        "gh run delete"
        # gh secret and gh variable: family-wide. Name listing is
        # carved out above (and `gh variable get` for non-secret
        # values); setting, deleting, and reading secret values stay
        # denied.
        "gh secret"
        "gh variable"
        # gh workflow: dispatch and enable/disable mutate CI state.
        "gh workflow disable"
        "gh workflow enable"
        "gh workflow run"
      ];
    };
  };
in
{
  config = lib.mkIf (host.is.linux && noughtyLib.userHasTag "developer") {
    home.packages = [
      fencePackage
      pkgs.bubblewrap
      pkgs.socat
      pkgs.bpftrace
    ];

    xdg.configFile."fence/fence.jsonc".text = builtins.toJSON fenceConfig;
  };
}
