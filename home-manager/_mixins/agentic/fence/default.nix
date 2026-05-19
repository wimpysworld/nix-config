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
        "~/.pi/**"

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

        # SOPS
        "${config.xdg.configHome}/sops/**"

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
        "gh auth token"
      ];
      deny = [
        "just switch"
        "just switch-home"
        "just switch-host"
        "git push"
        "git reset"
        "git clean"
        "git rebase"
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
        "python -c"
        "python3 -c"
        "node -e"
        "perl -e"
        "ruby -e"
        "lua -e"
        "php -r"
        "npm publish"
        "pnpm publish"
        "yarn publish"
        "cargo publish"
        "twine upload"
        "gem push"
        "gh api"
        "gh alias delete"
        "gh alias import"
        "gh alias set"
        "gh auth login"
        "gh auth logout"
        "gh auth refresh"
        "gh auth setup-git"
        "gh auth status"
        "gh auth switch"
        "gh cache delete"
        "gh codespace create"
        "gh codespace delete"
        "gh codespace edit"
        "gh codespace ports visibility"
        "gh codespace rebuild"
        "gh codespace stop"
        "gh cs create"
        "gh cs delete"
        "gh cs edit"
        "gh cs ports visibility"
        "gh cs rebuild"
        "gh cs stop"
        "gh config set"
        "gh extension browse"
        "gh extension exec"
        "gh extension install"
        "gh extension remove"
        "gh extension upgrade"
        "gh extensions browse"
        "gh extensions exec"
        "gh extensions install"
        "gh extensions remove"
        "gh extensions upgrade"
        "gh ext browse"
        "gh ext exec"
        "gh ext install"
        "gh ext remove"
        "gh ext upgrade"
        "gh gist delete"
        "gh gist edit"
        "gh gist rename"
        "gh gpg-key add"
        "gh gpg-key delete"
        "gh issue close"
        "gh issue delete"
        "gh issue lock"
        "gh issue transfer"
        "gh issue unlock"
        "gh label clone"
        "gh label create"
        "gh label delete"
        "gh label edit"
        "gh project close"
        "gh project delete"
        "gh project field-delete"
        "gh project item-archive"
        "gh project item-delete"
        "gh project unlink"
        "gh pr merge"
        "gh pr close"
        "gh pr lock"
        "gh pr unlock"
        "gh pr update-branch"
        "gh release new"
        "gh release create"
        "gh release delete"
        "gh release delete-asset"
        "gh release edit"
        "gh release upload"
        "gh repo create"
        "gh repo new"
        "gh repo archive"
        "gh repo autolink create"
        "gh repo autolink new"
        "gh repo autolink delete"
        "gh repo delete"
        "gh repo deploy-key add"
        "gh repo deploy-key delete"
        "gh repo edit"
        "gh repo rename"
        "gh repo sync"
        "gh repo unarchive"
        "gh run cancel"
        "gh run delete"
        "gh run rerun"
        "gh secret remove"
        "gh secret delete"
        "gh secret set"
        "gh ssh-key add"
        "gh ssh-key delete"
        "gh variable remove"
        "gh variable delete"
        "gh variable set"
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
