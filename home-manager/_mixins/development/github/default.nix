{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;
  gh-dispatch-gh = pkgs.runCommand "gh-dispatch-gh" { } ''
    mkdir -p "$out/bin"
    ln -s ${pkgs.gh}/bin/.gh-wrapped "$out/bin/gh-dispatch-gh"
  '';
  gh-api-safe-gh = pkgs.runCommand "gh-api-safe-gh" { } ''
    mkdir -p "$out/bin"
    ln -s ${pkgs.gh}/bin/.gh-wrapped "$out/bin/gh-api-safe-gh"
  '';
  gh-review-reply-gh = pkgs.runCommand "gh-review-reply-gh" { } ''
    mkdir -p "$out/bin"
    ln -s ${pkgs.gh}/bin/.gh-wrapped "$out/bin/gh-review-reply-gh"
  '';
  gh-review-resolve-gh = pkgs.runCommand "gh-review-resolve-gh" { } ''
    mkdir -p "$out/bin"
    ln -s ${pkgs.gh}/bin/.gh-wrapped "$out/bin/gh-review-resolve-gh"
  '';
  ghDashPackage = pkgs.symlinkJoin rec {
    pname = "gh-dash";
    version = pkgs.gh-dash.version;
    name = "${pname}-${version}-wrapped";
    paths = [ pkgs.gh-dash ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram "$out/bin/gh-dash" \
        --prefix PATH : "${gh-dispatch}/bin" \
        --set GH_TELEMETRY false
    '';
  };

  # Fence-friendly wrapper around `gh api`. Lives in the GitHub mixin
  # rather than the Fence mixin so the policy enforcement is available
  # to agents whether or not they are running under Fence. The script
  # implements its own allow-list, deny-list, and best-effort GraphQL
  # heuristic; see `gh-api-safe.sh` for the policy details.
  gh-api-safe = pkgs.writeShellApplication {
    name = "gh-api-safe";
    text = ''
      readonly GH_API_SAFE_GH=${lib.escapeShellArg "${gh-api-safe-gh}/bin/gh-api-safe-gh"}
    ''
    + builtins.readFile ./gh-api-safe.sh;
  };

  # Fence cannot enforce multi-token command rules after an agent starts a
  # shell under the path policy. This dispatcher applies the GitHub rules when
  # Fence sets FENCE_SANDBOX=1. Unfenced calls use the private backend without
  # policy checks, and raw fenced API reads use gh-api-safe.
  gh-dispatch = pkgs.writeShellApplication {
    name = "gh";
    text = ''
      readonly GH_DISPATCH_GH=${lib.escapeShellArg "${gh-dispatch-gh}/bin/gh-dispatch-gh"}
      readonly GH_DISPATCH_API_SAFE=${lib.escapeShellArg "${gh-api-safe}/bin/gh-api-safe"}
    ''
    + builtins.readFile ./gh-dispatch.sh;
  };
  ghPackage = pkgs.symlinkJoin {
    pname = "gh";
    version = "${pkgs.gh.version}-dispatched";
    name = "gh-${pkgs.gh.version}-dispatched";
    paths = [ pkgs.gh ];
    meta.mainProgram = "gh";
    postBuild = ''
      unlink "$out/bin/gh"
      ln -s ${gh-dispatch}/bin/gh "$out/bin/gh"
    '';
  };

  # Fence-friendly helper for replying inside a pull request review comment
  # thread. `gh` has no subcommand for it and `gh-api-safe` refuses every
  # POST by design, so this covers exactly one endpoint:
  # `repos/{owner}/{repo}/pulls/{pr}/comments/{id}/replies`. The script
  # validates every argument itself and builds the path from the validated
  # parts, so no other endpoint is reachable; see `gh-review-reply.sh`.
  gh-review-reply = pkgs.writeShellApplication {
    name = "gh-review-reply";
    runtimeInputs = [ pkgs.jq ];
    text = ''
      readonly GH_REVIEW_REPLY_GH=${lib.escapeShellArg "${gh-review-reply-gh}/bin/gh-review-reply-gh"}
    ''
    + builtins.readFile ./gh-review-reply.sh;
  };

  # Fence-friendly helper for marking a pull request review thread as
  # resolved. That is a GraphQL mutation only, `gh` has no subcommand for it,
  # and `gh-api-safe` is read-only, so this covers exactly one mutation:
  # `resolveReviewThread`. The script parses the thread out of a review
  # comment URL, sends every value as a typed GraphQL variable, and holds the
  # query and the mutation as fixed strings, so no other mutation is
  # reachable; see `gh-review-resolve.sh`.
  gh-review-resolve = pkgs.writeShellApplication {
    name = "gh-review-resolve";
    runtimeInputs = [ pkgs.jq ];
    text = ''
      readonly GH_REVIEW_RESOLVE_GH=${lib.escapeShellArg "${gh-review-resolve-gh}/bin/gh-review-resolve-gh"}
    ''
    + builtins.readFile ./gh-review-resolve.sh;
  };

  ghTokenVariables = [
    "GH_TOKEN"
    "GITHUB_TOKEN"
    "GHORG_GITHUB_TOKEN"
    "HOMEBREW_GITHUB_API_TOKEN"
  ];
  # `set -e` erases one variable per call. The fish body is a function, not an
  # alias: a fish alias appends `$argv` to its body, and a multi-line body
  # leaves `$argv` alone on a line, which fish rejects as an empty command.
  ghUnsetFish = lib.concatMapStringsSep "\n" (name: "set -e ${name}") ghTokenVariables;
  ghUnsetBash = "unset ${lib.concatStringsSep " " ghTokenVariables}";

  # The OAuth token `gh` stores never expires and has no refresh token, so
  # nothing refreshes it. The scopes `gh` asked for at login are the one thing
  # that goes stale, and only a browser device flow can add one. Every scope a
  # command in this configuration needs is listed here. `gh-credential-sync`
  # compares the list with the live token and leaves a marker that the shell
  # prompt reports, so a missing scope surfaces without a network call at shell
  # start.
  ghRequiredScopes = [
    "gist"
    "project"
    "read:org"
    "repo"
    "workflow"
  ];
  ghStateDir = "${config.xdg.stateHome}/gh";
  ghMissingScopesFile = "${ghStateDir}/missing-scopes";
  # Nix reads GitHub tokens from `access-tokens`, never from `GH_TOKEN`, so
  # the sync also writes the token into a file that the user `nix.conf`
  # includes. `!include` ignores a missing file, so a host that has never run
  # the sync loses nothing.
  nixAccessTokensFile = "${config.xdg.configHome}/nix/access-tokens.conf";

  ghCredentialSync = pkgs.writeShellApplication {
    name = "gh-credential-sync";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gh
      pkgs.jq
    ];
    text = ''
      required=(${lib.escapeShellArgs ghRequiredScopes})
      state_dir=${lib.escapeShellArg ghStateDir}
      missing_file=${lib.escapeShellArg ghMissingScopesFile}
      tokens_file=${lib.escapeShellArg nixAccessTokensFile}

      # Read the stored credential, never an inherited environment copy.
      unset GH_TOKEN GITHUB_TOKEN GH_ENTERPRISE_TOKEN GITHUB_ENTERPRISE_TOKEN
      mkdir -p "$state_dir" "$(dirname "$tokens_file")"

      if ! status_json="$(gh auth status --hostname github.com --active --json hosts 2>/dev/null)"; then
        echo "gh-credential-sync: not logged in to github.com" >&2
        printf 'not logged in\n' > "$missing_file"
        exit 0
      fi

      scopes="$(jq -r '.hosts["github.com"][] | select(.active) | .scopes // ""' <<< "$status_json")"
      missing=()
      for scope in "''${required[@]}"; do
        if ! grep -q -w -- "$scope" <<< "$scopes"; then
          missing+=("$scope")
        fi
      done

      if (( ''${#missing[@]} > 0 )); then
        printf '%s\n' "''${missing[@]}" > "$missing_file"
        echo "gh-credential-sync: token lacks scopes: ''${missing[*]}" >&2
      else
        rm -f "$missing_file"
      fi

      token="$(gh auth token --hostname github.com)"
      tmp="$(mktemp "$tokens_file.XXXXXX")"
      printf 'access-tokens = github.com=%s\n' "$token" > "$tmp"
      chmod 600 "$tmp"
      mv "$tmp" "$tokens_file"
    '';
  };

  # Print the pending scope warning, if any, without touching the network.
  ghScopeWarningBash = ''
    if [[ -s ${lib.escapeShellArg ghMissingScopesFile} ]]; then
      echo " GitHub token lacks: $(tr '\n' ' ' < ${lib.escapeShellArg ghMissingScopesFile})run 'gh auth refresh -s ${lib.concatStringsSep "," ghRequiredScopes}'"
    fi
  '';
  ghScopeWarningFish = ''
    if test -s ${lib.escapeShellArg ghMissingScopesFile}
      echo " GitHub token lacks: "(string join ' ' (cat ${lib.escapeShellArg ghMissingScopesFile}))" run 'gh auth refresh -s ${lib.concatStringsSep "," ghRequiredScopes}'"
    end
  '';

  # Opt-in export of the token into the current shell, for a tool that reads
  # only the environment and has no wrapper below. Nothing runs this at shell
  # start: an exported `GH_TOKEN` outranks the stored credential, so a shell
  # that inherited one never saw a later `gh auth refresh`.
  ghTokenBash = ''
    gh-token() {
      local auth_status
      auth_status=$(${pkgs.gh}/bin/gh auth status 2>&1)
      local status_code=$?

      if [ $status_code -eq 0 ]; then
        local token
        token=$(${pkgs.gh}/bin/gh auth token)
        ${lib.concatMapStringsSep "\n    " (name: "export ${name}=\"$token\"") ghTokenVariables}
      elif [[ "$auth_status" == *"SAML"* ]]; then
        echo " GitHub SAML session expired. Run 'gh auth refresh'"
        return 1
      else
        echo " GitHub not authenticated. Run 'gh auth login'"
        return 1
      fi
    }
  '';
  ghTokenFish = ''
    set -l auth_status (${pkgs.gh}/bin/gh auth status 2>&1)
    set -l status_code $status

    if test $status_code -eq 0
      set -l token (${pkgs.gh}/bin/gh auth token)
      ${lib.concatMapStringsSep "\n  " (name: "set -gx ${name} $token") ghTokenVariables}
    else if string match -q "*SAML*" $auth_status
      echo " GitHub SAML session expired. Run 'gh auth refresh'"
      return 1
    else
      echo " GitHub not authenticated. Run 'gh auth login'"
      return 1
    end
  '';

  # Tools that read a token only from the environment get it for one
  # invocation, read from the stored credential at that moment. Exposure stops
  # at the tool, and a refreshed token is used on the next call.
  toolWrappersBash =
    lib.optionalString host.is.workstation ''
      ghorg() {
        GHORG_GITHUB_TOKEN="$(${pkgs.gh}/bin/gh auth token)" command ghorg "$@"
      }
      act() {
        command act -s GITHUB_TOKEN="$(${pkgs.gh}/bin/gh auth token)" "$@"
      }
    ''
    + lib.optionalString host.is.darwin ''
      brew() {
        HOMEBREW_GITHUB_API_TOKEN="$(${pkgs.gh}/bin/gh auth token)" command brew "$@"
      }
    '';
  toolWrappersFish =
    lib.optionalAttrs host.is.workstation {
      ghorg = {
        wraps = "ghorg";
        body = "GHORG_GITHUB_TOKEN=(${pkgs.gh}/bin/gh auth token) command ghorg $argv";
      };
      act = {
        wraps = "act";
        body = "command act -s GITHUB_TOKEN=(${pkgs.gh}/bin/gh auth token) $argv";
      };
    }
    // lib.optionalAttrs host.is.darwin {
      brew = {
        wraps = "brew";
        body = "HOMEBREW_GITHUB_API_TOKEN=(${pkgs.gh}/bin/gh auth token) command brew $argv";
      };
    };

  shellAliases = {
    gh-login = "${pkgs.gh}/bin/gh auth login -p https -s ${lib.concatStringsSep "," ghRequiredScopes}";
    gh-refresh = "${pkgs.gh}/bin/gh auth refresh -s ${lib.concatStringsSep "," ghRequiredScopes}";
    gh-status = "${pkgs.gh}/bin/gh auth status";
    gh-sync = lib.getExe ghCredentialSync;
    gh-test = "${pkgs.openssh}/bin/ssh -T github.com";
  };
  bashShellAliases = shellAliases // {
    gh-unset = ghUnsetBash;
  };
in
lib.mkMerge [
  {
    home = {
      packages = [
        gh-api-safe
        gh-review-reply
        gh-review-resolve
        ghCredentialSync
      ];
    };

    # The user `nix.conf` only includes the token file the sync writes. Nix
    # reads this file for every fetch, so a refreshed token reaches flake
    # fetching without any environment variable.
    xdg.configFile."nix/nix.conf".text = ''
      !include ${nixAccessTokensFile}
    '';

    systemd.user = lib.mkIf host.is.linux {
      services.gh-credential-sync = {
        Unit.Description = "Check gh token scopes and write the Nix access token file";
        Service = {
          Type = "oneshot";
          ExecStart = lib.getExe ghCredentialSync;
        };
      };
      timers.gh-credential-sync = {
        Unit.Description = "Check gh token scopes on a schedule";
        Timer = {
          OnBootSec = "2m";
          OnUnitActiveSec = "6h";
          RandomizedDelaySec = "5m";
          Unit = "gh-credential-sync.service";
        };
        Install.WantedBy = [ "timers.target" ];
      };
    };

    launchd.agents.gh-credential-sync = lib.mkIf host.is.darwin {
      enable = true;
      config = {
        ProgramArguments = [ (lib.getExe ghCredentialSync) ];
        RunAtLoad = true;
        StartInterval = 6 * 60 * 60;
      };
    };

    programs = {
      bash = {
        shellAliases = bashShellAliases;
        initExtra = ''
          ${ghTokenBash}
          ${toolWrappersBash}
          if [[ $- == *i* ]]; then
            ${ghScopeWarningBash}
          fi
        '';
      };
      fish = {
        inherit shellAliases;
        functions = {
          gh-unset = {
            description = "Erase the GitHub token variables that gh-token exported";
            body = ghUnsetFish;
          };
          gh-token = {
            description = "Export the stored gh token into this shell";
            body = ghTokenFish;
          };
        }
        // toolWrappersFish;
        interactiveShellInit = ghScopeWarningFish;
      };
      gh = {
        enable = true;
        package = ghPackage;
        extensions = lib.optionals (!host.is.server) (
          with pkgs;
          [
            gh-enhance
            gh-markdown-preview
            gh-notify
          ]
        );
        settings = {
          #editor = "fresh";
          git_protocol = "https";
          prompt = "enabled";
        };
      };
      zsh = {
        shellAliases = bashShellAliases;
        initContent = lib.mkMerge [
          (lib.mkOrder 500 ''
            ${ghTokenBash}
            ${toolWrappersBash}
          '')
          (lib.mkOrder 1000 ''
            if [[ -o interactive ]]; then
              ${ghScopeWarningBash}
            fi
          '')
        ];
      };
    };
  }

  (lib.mkIf host.is.workstation {
    catppuccin.gh-dash = {
      enable = config.programs.gh-dash.enable;
      accent = "blue";
    };

    home = {
      packages =
        (with pkgs; [
          act # Run GitHub Actions locally
          actionlint
          ghbackup # Backup GitHub repositories
          ghorg # Clone all repositories in a GitHub organization
        ])
        ++ [
          inputs.nix-packages.packages.${pkgs.stdenv.hostPlatform.system}.tailor
        ];
      sessionVariables = {
        GHORG_CLONE_PROTOCOL = "https";
        GHORG_ABSOLUTE_PATH_TO_CLONE_TO = "${config.home.homeDirectory}/Development";
        GHORG_INCLUDE_SUBMODULES = "true";
        GHORG_COLOR = "enabled";
        GHORG_SKIP_ARCHIVED = "true";
        GHORG_SKIP_FORKS = "true";
      };
    };

    programs = {
      gh-dash = {
        enable = true;
        package = ghDashPackage;
        settings = {
          pager.diff = "${lib.getExe pkgs.diffnav}";
          prSections = [
            {
              title = "My Pull Requests";
              filters = "is:open author:@me";
            }
            {
              title = "Needs My Review";
              filters = "is:open review-requested:@me";
            }
            {
              title = "Involved";
              filters = "is:open involves:@me -author:@me";
            }
            {
              title = "All PRs";
              filters = "is:open";
            }
          ];
          issuesSections = [
            {
              title = "My Issues";
              filters = "is:open author:@me";
            }
            {
              title = "Assigned";
              filters = "is:open assignee:@me";
            }
            {
              title = "Involved";
              filters = "is:open involves:@me -author:@me";
            }
            {
              title = "All Issues";
              filters = "is:open";
            }
          ];
          keybindings.prs = [
            {
              # gh-dash runs built-in keys before custom commands.
              # Move built-in merge away from "m" so "m" can request auto-merge.
              key = "ctrl+x";
              name = "built-in merge";
              builtin = "merge";
            }
            {
              key = "m";
              name = "auto-merge";
              command = "gh pr merge --rebase --admin --delete-branch --repo '{{.RepoName}}' '{{.PrNumber}}'";
            }
            {
              key = "T";
              name = "enhance";
              command = "${lib.getExe gh-dispatch} enhance -R {{.RepoName}} {{.PrNumber}}";
            }
          ];
        };
      };
      zed-editor = lib.mkIf config.programs.zed-editor.enable {
        extensions = [
          "github-actions"
        ];
      };
    };

    sops = {
      secrets = {
        act-env = {
          path = "${config.xdg.configHome}/act/secrets";
          sopsFile = ../../../../secrets/act.yaml;
          mode = "0660";
        };
      };
    };
  })
]
