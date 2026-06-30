{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;
  gh-api-safe-gh = pkgs.runCommand "gh-api-safe-gh" { } ''
    mkdir -p "$out/bin"
    ln -s ${pkgs.gh}/bin/.gh-wrapped "$out/bin/gh-api-safe-gh"
  '';
  ghDashGh = pkgs.runCommand "gh-dash-gh" { } ''
    mkdir -p "$out/bin"
    ln -s ${pkgs.gh}/bin/.gh-wrapped "$out/bin/gh"
  '';
  ghDashPackage = pkgs.symlinkJoin rec {
    pname = "gh-dash";
    version = pkgs.gh-dash.version;
    name = "${pname}-${version}-wrapped";
    paths = [ pkgs.gh-dash ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram "$out/bin/gh-dash" \
        --prefix PATH : "${ghDashGh}/bin" \
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

  ghUnsetFish = ''
    set -e GH_TOKEN; set -e GITHUB_TOKEN; set -e GHORG_GITHUB_TOKEN; set -e HOMEBREW_GITHUB_API_TOKEN
  '';
  ghUnsetBash = ''
    unset GH_TOKEN GITHUB_TOKEN GHORG_GITHUB_TOKEN HOMEBREW_GITHUB_API_TOKEN
  '';
  ghorgTokenBash = lib.optionalString host.is.workstation ''
    export GHORG_GITHUB_TOKEN=$(${pkgs.gh}/bin/gh auth token)
  '';
  ghorgTokenFish = lib.optionalString host.is.workstation ''
    set -gx GHORG_GITHUB_TOKEN (${pkgs.gh}/bin/gh auth token)
  '';
  shellAliases = {
    gh-login = "${pkgs.gh}/bin/gh auth login -p https";
    gh-refresh = "${pkgs.gh}/bin/gh auth refresh";
    gh-status = "${pkgs.gh}/bin/gh auth status";
    gh-test = "${pkgs.openssh}/bin/ssh -T github.com";
    gh-unset = if config.programs.fish.enable then ghUnsetFish else ghUnsetBash;
  };
in
lib.mkMerge [
  {
    home = {
      packages = [
        gh-api-safe
      ];
    };

    programs = {
      bash = {
        inherit shellAliases;
        initExtra = ''
                    gh-token() {
                      # Capture status output and exit code
                      local auth_status
                      auth_status=$(${pkgs.gh}/bin/gh auth status 2>&1)
                      local status_code=$?

                      if [ $status_code -eq 0 ]; then
                        export GH_TOKEN=$(${pkgs.gh}/bin/gh auth token)
                        export GITHUB_TOKEN=$(${pkgs.gh}/bin/gh auth token)
          ${ghorgTokenBash}
                        export HOMEBREW_GITHUB_API_TOKEN=$(${pkgs.gh}/bin/gh auth token)
                      elif [[ "$auth_status" == *"SAML"* ]]; then
                        echo " GitHub SAML session expired. Run 'gh auth refresh'"
                        return 1
                      else
                        echo " GitHub not authenticated. Run 'gh auth login'"
                        return 1
                      fi
                    }

                    # Run gh-token automatically in interactive shells
                    if [[ $- == *i* ]]; then
                      gh-token
                    fi
        '';
      };
      fish = {
        inherit shellAliases;
        shellInitLast = ''
                    function gh-token
                      # Capture status output
                      set -l auth_status (${pkgs.gh}/bin/gh auth status 2>&1)
                      set -l status_code $status

                      if test $status_code -eq 0
                        set -gx GH_TOKEN (${pkgs.gh}/bin/gh auth token)
                        set -gx GITHUB_TOKEN (${pkgs.gh}/bin/gh auth token)
          ${ghorgTokenFish}
                        set -gx HOMEBREW_GITHUB_API_TOKEN (${pkgs.gh}/bin/gh auth token)
                      else if string match -q "*SAML*" $auth_status
                        echo " GitHub SAML session expired. Run 'gh auth refresh'"
                        return 1
                      else
                        echo " GitHub not authenticated. Run 'gh auth login'"
                        return 1
                      end
                    end

                    if status is-interactive
                      gh-token
                    end
        '';
      };
      gh = {
        enable = true;
        extensions = with pkgs; [
          gh-enhance
          gh-markdown-preview
          gh-notify
        ];
        settings = {
          #editor = "fresh";
          git_protocol = "https";
          prompt = "enabled";
        };
      };
      zsh = {
        inherit shellAliases;
        initContent =
          let
            # Early initialization for function definition
            zshConfigEarly = lib.mkOrder 500 ''
                            gh-token() {
                              # Capture status output and exit code
                              local auth_status
                              auth_status=$(${pkgs.gh}/bin/gh auth status 2>&1)
                              local status_code=$?

                              if [ $status_code -eq 0 ]; then
                                export GH_TOKEN=$(${pkgs.gh}/bin/gh auth token)
                                export GITHUB_TOKEN=$(${pkgs.gh}/bin/gh auth token)
              ${ghorgTokenBash}
                                export HOMEBREW_GITHUB_API_TOKEN=$(${pkgs.gh}/bin/gh auth token)
                              elif [[ "$auth_status" == *"SAML"* ]]; then
                                echo " GitHub SAML session expired. Run 'gh auth refresh'"
                                return 1
                              else
                                echo " GitHub not authenticated. Run 'gh auth login'"
                                return 1
                              fi
                            }
            '';

            # General configuration for auto-execution
            zshConfig = lib.mkOrder 1000 ''
              # Run gh-token automatically in interactive shells
              if [[ -o interactive ]]; then
                gh-token
              fi
            '';
          in
          lib.mkMerge [
            zshConfigEarly
            zshConfig
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
              command = "${lib.getExe pkgs.gh} enhance -R {{.RepoName}} {{.PrNumber}}";
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
