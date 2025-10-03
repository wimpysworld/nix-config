{
  config,
  lib,
  pkgs,
  ...
}:
let
  ghUnsetFish = ''
    set -e GH_TOKEN; set -e GITHUB_TOKEN; set -e GHORG_GITHUB_TOKEN; set -e HOMEBREW_GITHUB_API_TOKEN
  '';
  ghUnsetBash = ''
    unset GH_TOKEN GITHUB_TOKEN GHORG_GITHUB_TOKEN HOMEBREW_GITHUB_API_TOKEN
  '';
  shellAliases = {
    gh-login = "${pkgs.gh}/bin/gh auth login -p https";
    gh-refresh = "${pkgs.gh}/bin/gh auth refresh";
    gh-status = "${pkgs.gh}/bin/gh auth status";
    gh-test = "${pkgs.openssh}/bin/ssh -T github.com";
    gh-unset = if config.programs.fish.enable then ghUnsetFish else ghUnsetBash;
  };
in
{
  catppuccin.gh-dash.enable = config.programs.gh.extensions.gh-dash;

  home = {
    packages = with pkgs; [
      ghbackup # Backup GitHub repositories
      ghorg # Clone all repositories in a GitHub organization
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
            export GHORG_GITHUB_TOKEN=$(${pkgs.gh}/bin/gh auth token)
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
            set -gx GHORG_GITHUB_TOKEN (${pkgs.gh}/bin/gh auth token)
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
        gh-copilot
        gh-dash
        gh-markdown-preview
        gh-notify
      ];
      settings = {
        #editor = "micro";
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
                export GHORG_GITHUB_TOKEN=$(${pkgs.gh}/bin/gh auth token)
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
