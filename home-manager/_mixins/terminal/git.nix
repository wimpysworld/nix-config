{
  config,
  lib,
  pkgs,
  ...
}:
let
  gitsignCredentialCache =
    if pkgs.stdenv.isLinux then
      "${config.xdg.cacheHome}/sigstore/gitsign/cache.sock"
    else if pkgs.stdenv.isDarwin then
      "${config.home.homeDirectory}/Library/Caches/sigstore/gitsign/cache.sock"
    else
      "${config.home.homeDirectory}/.cache/sigstore/gitsign/cache.sock";
  shellAliases = {
    gitso = "${pkgs.git}/bin/git --signoff";
  };
in
{
  catppuccin = {
    delta.enable = config.programs.delta.enable;
    gitui.enable = config.programs.gitui.enable;
  };

  home = {
    file = {
      # Symlink ~/.gitconfig to ~/.config/git/config to prevent config divergence
      ".gitconfig".source = config.lib.file.mkOutOfStoreSymlink "${config.xdg.configHome}/git/config";
    };
    packages = with pkgs; [
      git-igitt # git log/graph
      gitsign # Sign Git commits and tags with Sigstore
      pre-commit # Git pre-commit hooks
    ];
    sessionVariables = {
      GITSIGN_CONNECTOR_ID = "https://accounts.google.com";
      GITSIGN_CREDENTIAL_CACHE = "${gitsignCredentialCache}";
    };
  };

  programs = {
    bash = {
      inherit shellAliases;
    };
    delta = {
      enable = true;
      enableGitIntegration = config.programs.git.enable;
      options = {
        hyperlinks = true;
        line-numbers = true;
        side-by-side = true;
      };
    };
    fish = {
      inherit shellAliases;
    };
    git = {
      enable = true;
      settings = {
        aliases = {
          ci = "commit";
          cl = "clone";
          co = "checkout";
          puff = "pull --ff-only";
          purr = "pull --rebase";
          fucked = "reset --hard";
          graph = "log --color --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit";
        };
        extraConfig = {
          advice = {
            statusHints = false;
          };
          diff = {
            colorMoved = "default";
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
      };
      ignores = [
        "*.log"
        "*.out"
        ".DS_Store"
        "bin/"
        "dist/"
        "direnv*"
        "result*"
      ];
    };
    gitui = {
      enable = true;
    };
    zsh = {
      inherit shellAliases;
    };
  };

  systemd.user = lib.mkIf pkgs.stdenv.isLinux {
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

  launchd.agents = lib.mkIf pkgs.stdenv.isDarwin {
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
