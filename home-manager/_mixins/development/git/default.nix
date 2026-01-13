{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (pkgs.stdenv) isLinux isDarwin;
  gitsignCredentialCache =
    if pkgs.stdenv.isLinux then
      "${config.xdg.cacheHome}/sigstore/gitsign/cache.sock"
    else if pkgs.stdenv.isDarwin then
      "${config.home.homeDirectory}/Library/Caches/sigstore/gitsign/cache.sock"
    else
      "${config.home.homeDirectory}/.cache/sigstore/gitsign/cache.sock";
  precommitSetup = pkgs.writeShellApplication {
    name = "pre-commit-setup";
    runtimeInputs = with pkgs; [
      nixpkgs-review
      pre-commit
    ];
    text = builtins.readFile ./pre-commit-setup.sh;
  };
  shellAliases = {
    gitso = "${pkgs.git}/bin/git --signoff";
  };
in
{
  catppuccin = {
    delta.enable = config.programs.delta.enable;
    lazygit.enable = config.programs.lazygit.enable;
  };

  home = {
    file = {
      # Symlink ~/.gitconfig to ~/.config/git/config to prevent config divergence
      ".gitconfig".source = config.lib.file.mkOutOfStoreSymlink "${config.xdg.configHome}/git/config";
    };
    packages =
      with pkgs;
      [
        git-igitt # git log/graph
        gitsign # Sign Git commits and tags with Sigstore
      ]
      # pre-commit and related tools require dotnet which is currently broken on Darwin
      ++ lib.optionals (!isDarwin) [
        pre-commit # Git pre-commit hooks
        precommitSetup
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
        side-by-side = false;
      };
    };
    fish = {
      inherit shellAliases;
    };
    git = {
      enable = true;
      settings = {
        alias = {
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
    lazygit = {
      enable = true;
      settings = {
        # Skip "Press enter to return to lazygit" after subprocesses
        promptToReturnFromSubprocess = false;
        # Skip intro popups when opening lazygit
        disableStartupPopups = true;
        # Nix manages the package, so disable update checks
        update.method = "never";
        # CUA-style keybindings
        keybinding = {
          universal = {
            quit = "<c-q>"; # Ctrl+Q to quit (CUA standard)
          };
        };
        git = {
          # Auto-fetch from remote periodically
          autoFetch = true;
          # Use delta for diffs with side-by-side view (pagers is an array)
          pagers = [
            { pager = "${pkgs.delta}/bin/delta --dark --paging=never"; }
          ];
        };
        gui = {
          # Show keybindings in the bottom status line (like gitui does)
          showBottomLine = true;
          # Show jump-to-window keybindings (1-5) in window titles
          showPanelJumps = true;
          # Show Nerd Font icons (requires Nerd Font in terminal)
          nerdFontsVersion = "3";
          # Show a random tip in the command log when lazygit starts
          showRandomTip = true;
          # Accordion effect - expand the focused side panel
          expandFocusedSidePanel = true;
          # Use fuzzy filtering when searching with '/'
          filterMode = "fuzzy";
          # Show all branches log instead of dashboard (hides donate link)
          statusPanelView = "allBranchesLog";
        };
      };
    };
    vscode = lib.mkIf config.programs.vscode.enable {
      profiles.default = {
        userSettings = {
          "git.openRepositoryInParentFolders" = "always";
        };
        extensions = with pkgs; [
          vscode-marketplace.codezombiech.gitignore
        ];
      };
    };
    zed-editor = lib.mkIf config.programs.zed-editor.enable {
      userSettings = {
        languages = {
          "Git Commit" = {
            soft_wrap = "editor_width";
            preferred_line_length = 72;
          };
        };
      };
      extensions = [
        "git-firefly"
      ];
    };
    zsh = {
      inherit shellAliases;
    };
  };

  sops = {
    secrets = {
      cg-repos = {
        path = "${config.home.homeDirectory}/.config/cg-repos";
        sopsFile = ../../../../secrets/cg-repos.yaml;
        mode = "0644";
      };
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
