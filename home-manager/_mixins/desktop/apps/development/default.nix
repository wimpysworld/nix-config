{
  catppuccinPalette,
  config,
  inputs,
  lib,
  pkgs,
  username,
  ...
}:
let
  installFor = [ "martin" ];
  inherit (pkgs.stdenv) isLinux isDarwin;
  vscodeUserDir =
    if isLinux then
      "${config.xdg.configHome}/Code/User"
    else if isDarwin then
      "/Users/${username}/Library/Application Support/Code/User"
    else
      throw "Unsupported platform";
in
lib.mkIf (lib.elem username installFor) {
  nixpkgs.overlays = [
    inputs.nix-vscode-extensions.overlays.default
  ];

  catppuccin = {
    vscode.profiles.default.enable = config.programs.vscode.enable;
    zed.enable = config.programs.zed-editor.enable;
  };

  # User specific dconf settings; only intended as override for NixOS dconf profile user database
  dconf.settings =
    with lib.hm.gvariant;
    lib.mkIf isLinux {
      "org/gnome/meld" = {
        custom-font = "FiraCode Nerd Font Mono Medium 13";
        indent-width = mkInt32 4;
        insert-spaces-instead-of-tabs = true;
        highlight-current-line = true;
        show-line-numbers = true;
        prefer-dark-theme = true;
        highlight-syntax = true;
        style-scheme = "catppuccin_${catppuccinPalette.flavor}";
      };
    };

  home = {
    file = {
      "${vscodeUserDir}/mcp.json".text = builtins.readFile ./mcp.json;
      "${vscodeUserDir}/prompts/copilot.instructions.md".text =
        builtins.readFile ./copilot.instructions.md;
      "${vscodeUserDir}/prompts/dummy.prompt.md".text = builtins.readFile ./copilot.instructions.md;
      "${vscodeUserDir}/prompts/dilbert.agent.md".text = builtins.readFile ./dilbert.agent.md;
      "${vscodeUserDir}/prompts/gonzales.agent.md".text = builtins.readFile ./gonzales.agent.md;
      "${vscodeUserDir}/prompts/linus.agent.md".text = builtins.readFile ./linus.agent.md;
      "${vscodeUserDir}/prompts/luthor.agent.md".text = builtins.readFile ./luthor.agent.md;
      "${vscodeUserDir}/prompts/nixpert.agent.md".text = builtins.readFile ./nixpert.agent.md;
      "${vscodeUserDir}/prompts/otto.agent.md".text = builtins.readFile ./otto.agent.md;
      "${vscodeUserDir}/prompts/penry.agent.md".text = builtins.readFile ./penry.agent.md;
      "${vscodeUserDir}/prompts/rosey.agent.md".text = builtins.readFile ./rosey.agent.md;
      "${vscodeUserDir}/prompts/velma.agent.md".text = builtins.readFile ./velma.agent.md;
      "${vscodeUserDir}/prompts/agent-create.prompt.md".text = builtins.readFile ./agent-create.prompt.md;
      "${vscodeUserDir}/prompts/agent-optimise.prompt.md".text =
        builtins.readFile ./agent-optimise.prompt.md;
      "${vscodeUserDir}/prompts/create-code.prompt.md".text = builtins.readFile ./create-code.prompt.md;
      "${vscodeUserDir}/prompts/create-conventional-commit.prompt.md".text =
        builtins.readFile ./create-conventional-commit.prompt.md;
      "${vscodeUserDir}/prompts/create-readme.prompt.md".text =
        builtins.readFile ./create-readme.prompt.md;
      "${vscodeUserDir}/prompts/offboard.prompt.md".text = builtins.readFile ./offboard.prompt.md;
      "${vscodeUserDir}/prompts/onboard.prompt.md".text = builtins.readFile ./onboard.prompt.md;
      "${vscodeUserDir}/prompts/orientate.prompt.md".text = builtins.readFile ./orientate.prompt.md;
      "${vscodeUserDir}/prompts/plan-code.prompt.md".text = builtins.readFile ./plan-code.prompt.md;
      "${vscodeUserDir}/prompts/plan-docs.prompt.md".text = builtins.readFile ./plan-docs.prompt.md;
      "${vscodeUserDir}/prompts/review-code.prompt.md".text = builtins.readFile ./review-code.prompt.md;
      "${vscodeUserDir}/prompts/review-naming.prompt.md".text =
        builtins.readFile ./review-naming.prompt.md;
      "${vscodeUserDir}/prompts/review-performance.prompt.md".text =
        builtins.readFile ./review-performance.prompt.md;
      "${vscodeUserDir}/prompts/review-pull-request-feedback.prompt.md".text =
        builtins.readFile ./review-pull-request-feedback.prompt.md;
      "${vscodeUserDir}/prompts/review-tests.prompt.md".text = builtins.readFile ./review-tests.prompt.md;
      "${vscodeUserDir}/prompts/update-docs.prompt.md".text = builtins.readFile ./update-docs.prompt.md;
      # https://github.com/catppuccin/gitkraken
      #  - I used the now 404: https://github.com/davi19/gitkraken
      "${config.home.homeDirectory}/.gitkraken/themes/catppuccin_mocha.jsonc".text =
        builtins.readFile ./gitkraken-catppuccin-mocha-blue-upstream.json;
      "${config.home.homeDirectory}/.local/share/libgedit-gtksourceview-300/styles/catppuccin-mocha.xml".text =
        builtins.readFile ./gedit-catppuccin-mocha.xml;
    };
    # Packages that are used by some of the extensions below
    packages = with pkgs; [
      bash-language-server
      gitkraken
      gk-cli
      go
      gopls
      luaformatter
      luajit
      lua-language-server
      unstable.mcp-nixos
      meld
      nil
      nixfmt-rfc-style
      nodePackages.prettier
      nodejs_24
      python3
      uv
      shellcheck
      shfmt
      stylua
    ];
  };

  programs = {
    vscode = {
      enable = true;
      profiles.default = {
        enableExtensionUpdateCheck = false;
        enableUpdateCheck = false;
        userSettings = {
          # Set to `true` to disable folding arrows next to folder icons.
          "catppuccin-icons.hidesExplorerArrows" = false;
          # Set to `false` to only use the default folder icon.
          "catppuccin-icons.specificFolders" = true;
          # Set to `true` to only use the `text` fill color for all icons.
          "catppuccin-icons.monochrome" = false;
          "chat.mcp.autostart" = "newAndOutdated";
          "chat.mcp.discovery.enabled" = true;
          "chat.mcp.enabled" = true;
          "cSpell.diagnosticLevel" = "Hint";
          "dart.updateDevTools" = false;
          "dart.checkForSdkUpdates" = false;
          "editor.bracketPairColorization.independentColorPoolPerBracketType" = true;
          "editor.fontSize" = 16;
          "editor.fontFamily" = "FiraCode Nerd Font Mono";
          "editor.fontLigatures" = true;
          # fontWeight:
          # 300 - Light
          # 400 - Regular
          # 450 - Retina (only works with FiraCode-VF.ttf installed, see below when using separated font files)
          # 500 - Medium
          # 600 - Bold
          "editor.fontWeight" = "400";
          "editor.guides.bracketPairs" = true;
          "editor.guides.bracketPairsHorizontal" = true;
          "editor.inlineSuggest.enabled" = true;
          "editor.renderWhitespace" = "all";
          "editor.rulers" = [
            80
            88
          ];
          "editor.semanticHighlighting.enabled" = true;
          "explorer.confirmDragAndDrop" = false;
          "extensions.ignoreRecommendations" = true;
          "[dart]"."editor.formatOnSave" = true;
          "[dart]"."editor.formatOnType" = true;
          "[dart]"."editor.rulers" = [ 80 ];
          "[dart]"."editor.selectionHighlight" = false;
          "[dart]"."editor.suggest.snippetsPreventQuickSuggestions" = false;
          "[dart]"."editor.suggestSelection" = "first";
          "[dart]"."editor.tabCompletion" = "onlySnippets";
          "[dart]"."editor.wordBasedSuggestions" = "off";
          "[dockerfile]"."editor.quickSuggestions.strings" = true;
          "[lua]"."editor.defaultFormatter" = "JohnnyMorganz.stylua";
          "[nix]"."editor.defaultFormatter" = "jnoortheen.nix-ide";
          "[nix]"."editor.formatOnSave" = true;
          "[nix]"."editor.tabSize" = 2;
          "[python]"."editor.formatOnType" = true;
          "[xml]"."editor.defaultFormatter" = "DotJoshJohnson.xml";
          "files.insertFinalNewline" = true;
          "files.trimTrailingWhitespace" = true;
          "git.openRepositoryInParentFolders" = "always";
          "github.copilot.chat.agent.thinkingTool" = true;
          "github.copilot.chat.codesearch.enabled" = true;
          "githubPullRequests.pullBranch" = "never";
          "markdown.preview.breaks" = true;
          "nix.enableLanguageServer" = true;
          "nix.serverPath" = "nil";
          "nix.serverSettings" = {
            "nil" = {
              "formatting" = {
                "command" = [ "nixfmt" ];
              };
            };
          };
          "partialDiff.enableTelemetry" = false;
          "projectManager.git" = {
            baseFolders = [
              "~/Chainguard"
              "~/Development"
              "~/Websites"
              "~/Zero"
            ];
            maxDepthRecursion = 5;
          };
          "redhat.telemetry.enabled" = false;
          "security.workspace.trust.untrustedFiles" = "open";
          "shellcheck.run" = "onSave";
          "shellformat.useEditorConfig" = true;
          "telemetry.feedback.enabled" = false;
          "telemetry.telemetryLevel" = "off";
          "terminal.integrated.fontSize" = 16;
          "terminal.integrated.fontFamily" = "FiraCode Nerd Font Mono";
          "terminal.integrated.fontWeight" = "400";
          "terminal.integrated.fontWeightBold" = "600";
          "terminal.integrated.scrollback" = 10240;
          "terminal.integrated.copyOnSelection" = true;
          "terminal.integrated.cursorBlinking" = true;
          "update.mode" = "none";
          "vsicons.dontShowNewVersionMessage" = true;
          "window.controlsStyle" =
            if config.wayland.windowManager.hyprland.enable then "hidden" else "native";
          "workbench.tree.indent" = 20;
          "workbench.startupEditor" = "none";
          "workbench.editor.empty.hint" = "hidden";
          "github.copilot.chat.commitMessageGeneration.instructions.text" = ''
            # Git Commit Message Generator

            Output ONLY the commit message. No explanations, no questions, no commentary.

            ## Format
            ```
            <type>(<optional scope>): <description>

            <body>

            [optional footer(s)]
            ```

            ## Types

            - **feat**: New features (MINOR version)
            - **fix**: Bug fixes (PATCH version)
            - **build**: Build system or dependencies
            - **chore**: Maintenance tasks
            - **ci**: CI/CD configuration
            - **docs**: Documentation
            - **i18n**: Internationalisation/localisation
            - **perf**: Performance improvements
            - **refactor**: Code restructuring (no behaviour change)
            - **revert**: Undo previous commits
            - **style**: Formatting/whitespace (no logic change)
            - **test**: Test cases or infrastructure

            ## Constraints

            **Description:**
            - Maximum 72 characters
            - Imperative mood ("add feature" not "added feature")
            - Lowercase, no trailing period
            - Do not repeat the type as first word

            **Body:**
            - Blank line after description
            - Explain what changed and why
            - Small changes: one sentence
            - Large changes: bulleted list using "-"

            **Breaking Changes:**
            - Indicate with `!` before colon: `feat!: remove deprecated API`
            - Or as footer: `BREAKING CHANGE: description`
            - BREAKING CHANGE must be uppercase

            **Footers:**
            - One blank line after body
            - Format: `Token: value` or `Token #value`
            - Use hyphens in multi-word tokens (e.g., `Acked-by`)
            - Exception: BREAKING CHANGE (space allowed)
          '';
        };
        extensions =
          with pkgs;
          [
            vscode-marketplace.aaron-bond.better-comments
            vscode-marketplace.alefragnani.project-manager
            vscode-marketplace.alexgb.nelua
            vscode-marketplace.anthropic.claude-code
            vscode-marketplace.bmalehorn.shell-syntax
            vscode-marketplace.bmalehorn.vscode-fish
            vscode-marketplace.budparr.language-hugo-vscode
            vscode-marketplace.catppuccin.catppuccin-vsc-icons
            vscode-marketplace.codezombiech.gitignore
            vscode-marketplace.coolbear.systemd-unit-file
            vscode-marketplace.dart-code.dart-code
            vscode-marketplace.dart-code.flutter
            vscode-marketplace.dotjoshjohnson.xml
            vscode-marketplace.editorconfig.editorconfig
            vscode-marketplace.eliostruyf.vscode-front-matter
            vscode-marketplace.esbenp.prettier-vscode
            vscode-marketplace.evan-buss.font-switcher
            vscode-marketplace.fill-labs.dependi
            vscode-marketplace.foxundermoon.shell-format
            vscode-marketplace.github.copilot
            vscode-marketplace.github.copilot-chat
            vscode-marketplace.github.vscode-github-actions
            vscode-marketplace.github.vscode-pull-request-github
            vscode-marketplace.golang.go
            vscode-marketplace.griimick.vhs
            #vscode-marketplace.hashicorp.terraform
            vscode-marketplace.hoovercj.vscode-power-mode
            vscode-marketplace.ismoh-games.second-local-lua-debugger-vscode
            vscode-marketplace.jdemille.debian-control-vscode
            vscode-marketplace.jeff-hykin.better-csv-syntax
            vscode-marketplace.jeff-hykin.better-dockerfile-syntax
            vscode-marketplace.jeff-hykin.better-nix-syntax
            vscode-marketplace.jeff-hykin.better-shellscript-syntax
            vscode-marketplace.jeff-hykin.polacode-2019
            vscode-marketplace.jeroen-meijer.pubspec-assist
            vscode-marketplace.jnoortheen.nix-ide
            vscode-marketplace.johnnymorganz.stylua
            vscode-marketplace.marp-team.marp-vscode
            vscode-marketplace.mechatroner.rainbow-csv
            vscode-marketplace.mkhl.direnv
            vscode-marketplace.ms-python.debugpy
            vscode-marketplace.ms-python.python
            vscode-marketplace.ms-python.vscode-pylance
            vscode-marketplace.ms-vscode.cmake-tools
            vscode-marketplace.ms-vscode.hexeditor
            vscode-extensions.ms-vscode-remote.vscode-remote-extensionpack
            vscode-marketplace.nefrob.vscode-just-syntax
            vscode-marketplace.nico-castell.linux-desktop-file
            vscode-marketplace.pixelbyte-studios.pixelbyte-love2d
            vscode-marketplace.pkief.material-product-icons
            vscode-marketplace.prince781.vala
            vscode-marketplace.pollywoggames.pico8-ls
            vscode-marketplace.redhat.vscode-yaml
            vscode-marketplace.rogalmic.bash-debug
            vscode-marketplace.rust-lang.rust-analyzer
            vscode-marketplace.ryu1kn.partial-diff
            vscode-marketplace.s3anmorrow.openwithkraken
            vscode-marketplace.sanjulaganepola.github-local-actions
            vscode-marketplace.slevesque.shader
            vscode-marketplace.streetsidesoftware.code-spell-checker
            vscode-marketplace.tamasfe.even-better-toml
            vscode-marketplace.timonwong.shellcheck
            vscode-marketplace.trond-snekvik.simple-rst
            vscode-marketplace.twxs.cmake
            vscode-marketplace.tobiashochguertel.just-formatter
            vscode-marketplace.unifiedjs.vscode-mdx
            vscode-marketplace.viktorzetterstrom.non-breaking-space-highlighter
            vscode-marketplace.vscode-icons-team.vscode-icons
            vscode-marketplace.xyc.vscode-mdx-preview
            vscode-marketplace.yinfei.luahelper
            vscode-marketplace.yzhang.markdown-all-in-one
          ]
          ++ lib.optionals isLinux [
            vscode-extensions.ms-vscode.cpptools-extension-pack
            vscode-extensions.ms-vsliveshare.vsliveshare
            vscode-extensions.vadimcn.vscode-lldb
          ];
      };
      mutableExtensionsDir = true;
      package = pkgs.unstable.vscode;
    };
    zed-editor = {
      enable = true;
      extensions = [
        "github-actions"
        "lua"
        "nix"
      ];
      package = pkgs.unstable.zed-editor;
      userSettings = {
        "languages" = {
          "Nix" = {
            "formatter" = {
              "external" = {
                "command" = "nixfmt";
                "arguments" = [
                  "--quiet"
                  "--"
                ];
              };
            };
            "language_servers" = [
              "nil"
              "!nixd"
            ];
          };
        };
        "lsp" = {
          "nil" = {
            "settings" = {
              "diagnostics" = {
                "ignored" = [ "unused_binding" ];
              };
            };
          };
        };
      };
    };
  };
  services.vscode-server.enable = true;
}
