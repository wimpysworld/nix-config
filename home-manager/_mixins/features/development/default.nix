{
  config,
  hostname,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  inherit (pkgs.stdenv) isDarwin isLinux;
  waveboxXdgOpen = inputs.xdg-override.lib.proxyPkg {
    inherit pkgs;
    nameMatch = [
      { case = "^https?://accounts.google.com/o/oauth2"; command = "wavebox"; }
      { case = "^https?://github.com/login/device"; command = "wavebox"; }
      { case = "^https?://auth.chainguard.dev/activate"; command = "wavebox"; }
      { case = "^https?://issuer.enforce.dev"; command = "wavebox"; }
    ];
  };
  cgTokens = pkgs.writeShellApplication {
    name = "cg-tokens";
    runtimeInputs = with pkgs; [
      gnugrep
      jq
      uutils-coreutils-noprefix
    ];
    text = builtins.readFile ./cg-tokens.sh;
  };
  dockerPurge = pkgs.writeShellApplication {
    name = "docker-purge";
    runtimeInputs = with pkgs; [
      docker
      jq
      uutils-coreutils-noprefix
    ];
    text = ''
      echo "⬢ WARNING: This will stop and remove all Docker images/containers on your system."
      # shellcheck disable=SC2162
      read -p "Are you sure you want to continue? (y/N): " confirm
      if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        exit 1
      fi
      for ID in $(docker images --format json | jq -r .ID); do
        docker stop "$(docker ps -aq --filter ancestor="$ID")" || true
        docker rmi -f "$ID" || true
      done
    '';
  };
  downloadPackage = pkgs.writeShellApplication {
    name = "download-package";
    runtimeInputs = with pkgs; [
      curl
      jq
      uutils-coreutils-noprefix
    ];
    text = builtins.readFile ./download-package.sh;
  };
  extractPackage = pkgs.writeShellApplication {
    name = "extract-package";
    runtimeInputs = with pkgs; [
      gnutar
      uutils-coreutils-noprefix
    ];
    text = builtins.readFile ./extract-package.sh;
  };
  graphImage = pkgs.writeShellApplication {
    name = "graph-image";
    runtimeInputs = with pkgs; [
      apko
      crane
      graphviz
      uutils-coreutils-noprefix
    ];
    text = builtins.readFile ./graph-image.sh;
  };
  graphPackage = pkgs.writeShellApplication {
    name = "graph-package";
    runtimeInputs = with pkgs; [
      apko
      graphviz
      uutils-coreutils-noprefix
    ];
    text = builtins.readFile ./graph-package.sh;
  };
  sbomInspect = pkgs.writeShellApplication {
    name = "sbom-inspect";
    runtimeInputs = with pkgs; [
      crane
      gnutar
      jq
      uutils-coreutils-noprefix
    ];
    text = builtins.readFile ./sbom-inspect.sh;
  };
  gitsignSetup = pkgs.writeShellApplication {
    name = "gitsign-setup";
    runtimeInputs = with pkgs; [
      git
      gitsign
    ];
    text = builtins.readFile ./gitsign-setup.sh;
  };
  gitsignOff = pkgs.writeShellApplication {
    name = "git-signoff";
    runtimeInputs = with pkgs; [
      git
    ];
    text = ''[ -d .git ] && git commit --amend --signoff --no-edit'';
  };
  gitsignVerify = pkgs.writeShellApplication {
    name = "gitsign-verify";
    runtimeInputs = with pkgs; [
      gitsign
    ];
    text = ''[ -d .git ] && gitsign verify --certificate-identity=martin.wimpress@chainguard.dev --certificate-oidc-issuer=https://accounts.google.com HEAD'';
  };
  precommitSetup = pkgs.writeShellApplication {
    name = "pre-commit-setup";
    runtimeInputs = with pkgs; [
      pre-commit
    ];
    text = builtins.readFile ./pre-commit-setup.sh;
  };
  installChainctl = pkgs.writeShellApplication {
    name = "install-chainctl";
    runtimeInputs = with pkgs; [
      curl
      uutils-coreutils-noprefix
    ];
    text = builtins.readFile ./install-chainctl.sh;
  };
  gitsignCredentialCache = if isLinux then
    "${config.xdg.cacheHome}/sigstore/gitsign/cache.sock"
  else if isDarwin then
    "${config.home.homeDirectory}/Library/Caches/sigstore/gitsign/cache.sock"
  else
    "${config.home.homeDirectory}/.cache/sigstore/gitsign/cache.sock";
in
{
  # Enable the Catppuccin theme
  catppuccin = {
    gh-dash.enable = config.programs.gh.extensions.gh-dash;
    gitui.enable = config.programs.gitui.enable;
  };

  home = {
    file = {
      "${config.xdg.configHome}/fish/functions/h.fish".text = builtins.readFile ../../../_mixins/configs/h.fish;
      # Symlink ~/.gitconfig to ~/.config/git/config to prevent config divergence
      ".gitconfig".source = config.lib.file.mkOutOfStoreSymlink "${config.xdg.configHome}/git/config";
    };
    sessionPath = [
      "${config.home.homeDirectory}/.local/go/bin"
    ];
    sessionVariables = {
      GHORG_CLONE_PROTOCOL = "https";
      GHORG_ABSOLUTE_PATH_TO_CLONE_TO = "${config.home.homeDirectory}/Development";
      GHORG_INCLUDE_SUBMODULES = "true";
      GHORG_COLOR = "enabled";
      GHORG_SKIP_ARCHIVED = "true";
      GHORG_SKIP_FORKS = "true";
      GITSIGN_CONNECTOR_ID = "https://accounts.google.com";
      GITSIGN_CREDENTIAL_CACHE = "${gitsignCredentialCache}";
      GOPATH = "${config.home.homeDirectory}/.local/go";
      GOCACHE = "${config.home.homeDirectory}/.local/go/cache";
    };
    packages =
      with pkgs;
      [
        cgTokens
        dockerPurge
        downloadPackage
        extractPackage
        graphImage
        graphPackage
        sbomInspect
        installChainctl
        gitsignSetup
        gitsignOff
        gitsignVerify
        precommitSetup
        unstable.apko # Declarative container images
        unstable.claude-code # Claude Code CLI
        cosign # Sign and verify container images
        crane # Container registry client
        dive # Explore container images
        difftastic # Modern Unix `diff`
        ghbackup # Backup GitHub repositories
        ghorg # Clone all repositories in a GitHub organization
        git-igitt # git log/graph
        gitsign # Sign git commits and tags
        gk-cli # GitKraken CLI
        gnumake # GNU Make
        go # Go programming language
        google-cloud-sdk # Google Cloud CLI
        unstable.grype # Vulnerability scanner
        h # autojump for git projects
        k3d # Lightweight Kubernetes
        kind # Kubernetes in Docker
        unstable.melange # Declarative package manager
        onefetch # fetch git project info
        pre-commit # Git pre-commit hooks
        quilt # patch manager
        terraform # Infrastructure as code tool
        tokei # Modern Unix `wc` for code
        unstable.syft # SBOM scanner
        wolfictl # Wolfi OSS project CLI
      ] ++ lib.optionals isLinux [
        waveboxXdgOpen # Integrate Wavebox with Slack, GitHub, Auth, etc.
      ];
  };

  programs = {
    fish = {
      shellAliases = {
        gh-login = "${pkgs.gh}/bin/gh auth login -p https";
        gh-refresh = "${pkgs.gh}/bin/gh auth refresh";
        gh-status = "${pkgs.gh}/bin/gh auth status";
        gh-test = "${pkgs.openssh}/bin/ssh -T github.com";
        gh-unset = "set -e GH_TOKEN; set -e GITHUB_TOKEN; set -e GHORG_GITHUB_TOKEN; set -e HOMEBREW_GITHUB_API_TOKEN";
        gitso = "${pkgs.git}/bin/git --signoff";
        install-cdebug = "go install github.com/iximiuz/cdebug@latest";
        install-yam = "go install github.com/chainguard-dev/yam@latest";
        install-wolfi-package-status = "go install github.com/philroche/wolfi-package-status@latest";
        key-add = "${pkgs.openssh}/bin/ssh-add $HOME/.ssh/id_ed25519_sk_${hostname}";
        mal = "docker run -it cgr.dev/chainguard/malcontent:latest";
      };
      shellInitLast = ''
        function gh-token
          # Capture status output
          set -l auth_status (${pkgs.gh}/bin/gh auth status 2>&1)
          set -l status_code $status

          if test $status_code -eq 0
            echo " GitHub authenticated"
            set -gx GH_TOKEN (${pkgs.gh}/bin/gh auth token)
            set -gx GH_USER flexiondotorg
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
          set h (date --utc +%H)
          set dow (date --utc +%u)
          if test $h -ge 7 -a $h -le 19 -a $dow -le 5
            if test (uname) = Darwin
              cg-tokens --browser
            else
              # Linux - check for display server
              if test -n "$WAYLAND_DISPLAY" -o -n "$DISPLAY"
                cg-tokens --browser
              else
                cg-tokens --headless
              end
            end
          end
          gh-token
        end
      '';
    };
    gh = {
      enable = true;
      # TODO: Package https://github.com/DevAtDawn/gh-fish
      extensions = with pkgs; [
        gh-copilot
        gh-dash
        gh-markdown-preview
        gh-notify
      ];
      settings = {
        editor = "micro";
        git_protocol = "https";
        prompt = "enabled";
      };
    };
    git = {
      enable = true;
      aliases = {
        ci = "commit";
        cl = "clone";
        co = "checkout";
        puff = "pull --ff-only";
        purr = "pull --rebase";
        dlog = "!f() { GIT_EXTERNAL_DIFF=difft git log -p --ext-diff $@; }; f";
        dshow = "!f() { GIT_EXTERNAL_DIFF=difft git show --ext-diff $@; }; f";
        fucked = "reset --hard";
        graph = "log --color --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit";
      };
      difftastic = {
        display = "side-by-side-show-both";
        enable = true;
      };
      extraConfig = {
        advice = {
          statusHints = false;
        };
        color = {
          branch = false;
          diff = false;
          interactive = true;
          log = false;
          status = true;
          ui = false;
        };
        core = {
          pager = "bat";
        };
        push = {
          default = "matching";
        };
        pull = {
          rebase = false;
        };
        init = {
          defaultBranch = "main";
        };
      };
      ignores = [
        "*.log"
        "*.out"
        ".DS_Store"
        "bin/"
        "dist/"
        "result"
      ];
    };
    gitui = {
      enable = true;
    };
  };
  # https://dl.thalheim.io/
  sops = {
    secrets = {
      act-env = {
        path = "${config.home.homeDirectory}/.config/act/secrets";
        sopsFile = ../../../../secrets/act.yaml;
        mode = "0660";
      };
      cg-repos = {
        path = "${config.home.homeDirectory}/.config/cg-repos";
        sopsFile = ../../../../secrets/cg-repos.yaml;
        mode = "0644";
      };
      gh_token = {
        sopsFile = ../../../../secrets/github.yaml;
      };
      gh_read_only = {
        sopsFile = ../../../../secrets/github.yaml;
      };
    };
  };

  systemd.user = lib.mkIf isLinux {
    services.gitsign-credential-cache = {
      Unit = {
        Description = "GitSign credential cache";
      };
      Service = {
        Type = "simple";
        ExecStart = "${pkgs.gitsign}/bin/gitsign-credential-cache";
      };
      Install = {
        WantedBy = [ "default.target" ];
      };
    };

    sockets.gitsign-credential-cache = {
      Unit = {
        Description = "GitSign credential cache socket";
      };
      Socket = {
        ListenStream = "${gitsignCredentialCache}";
        DirectoryMode = "0700";
      };
      Install = {
        WantedBy = [ "default.target" ];
      };
    };

    # Enable and start the socket by default
    targets.gitsign-credential-cache = {
      Unit = {
        Description = "Start gitsign-credential-cache socket";
        Requires = [ "gitsign-credential-cache.socket" ];
      };
      Install = {
        WantedBy = [ "default.target" ];
      };
    };
  };

  launchd.agents = lib.mkIf isDarwin {
    gitsign-credential-cache = {
      enable = true;
      config = {
        Label = "org.sigstore.gitsign-credential-cache";
        ProgramArguments = [
          "${pkgs.gitsign}/bin/gitsign-credential-cache"
        ];
        KeepAlive = true;
        RunAtLoad = true;
      };
    };
  };
}
