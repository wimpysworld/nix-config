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
  gitsignXdgOpen = inputs.xdg-override.lib.proxyPkg {
    inherit pkgs;
    nameMatch = [
      { case = "^https?://accounts.google.com/"; command = "wavebox"; }
    ];
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
    name = "gitsign-off";
    runtimeInputs = with pkgs; [
      git
      gitsign
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
    };
    sessionPath = [
      "${config.home.homeDirectory}/.local/go/bin"
    ];
    sessionVariables = {
      GHORG_CLONE_PROTOCOL = "ssh";
      GHORG_ABSOLUTE_PATH_TO_CLONE_TO = "${config.home.homeDirectory}/Development";
      GHORG_INCLUDE_SUBMODULES = "true";
      GHORG_COLOR = "enabled";
      GHORG_SKIP_ARCHIVED = "true";
      GHORG_SKIP_FORKS = "true";
      GHORG_GITHUB_TOKEN = "${config.sops.secrets.gh_read_only.path}";
      GITSIGN_CONNECTOR_ID = "https://accounts.google.com";
      GITSIGN_CREDENTIAL_CACHE = "${gitsignCredentialCache}";
      GOPATH = "${config.home.homeDirectory}/.local/go";
      GOCACHE = "${config.home.homeDirectory}/.local/go/cache";
    };
    packages =
      with pkgs;
      [
        gitsignSetup
        gitsignOff
        gitsignVerify
        precommitSetup
        unstable.apko # Declarative container images
        chainctl # Chainguard Platform CLI
        cosign # Sign and verify container images
        crane # Container registry client
        dive # Explore container images
        difftastic # Modern Unix `diff`
        ghbackup # Backup GitHub repositories
        ghorg # Clone all repositories in a GitHub organization
        git-igitt # git log/graph
        gitsign # Sign git commits and tags
        gk-cli # GitKraken CLI
        go # Go programming language
        google-cloud-sdk # Google Cloud CLI
        unstable.grype # Vulnerability scanner
        h # autojump for git projects
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
        gitsignXdgOpen # Use Wavebox to open Google accounts
      ];
  };

  programs = {
    fish = {
      shellAliases = {
        chainctl-auth-docker = "chainctl auth configure-docker --headless";
        gh-auth = "${pkgs.gh}/bin/gh auth login -p ssh";
        install-cdebug = "go install github.com/iximiuz/cdebug@latest";
        install-yam = "go install github.com/chainguard-dev/yam@latest";
        key-add = "${pkgs.openssh}/bin/ssh-add $HOME/.ssh/id_ed25519_sk_${hostname}";
      };
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
        git_protocol = "ssh";
        prompt = "enabled";
      };
    };
    git = {
      enable = true;
      aliases = {
        ci = "commit";
        cl = "clone";
        co = "checkout";
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
          "-socket"
          "${gitsignCredentialCache}"
        ];
        KeepAlive = true;
        RunAtLoad = true;
      };
    };
  };
}
