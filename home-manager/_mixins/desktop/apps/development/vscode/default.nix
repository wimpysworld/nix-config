{
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
    };
    # Packages that are used by some of the extensions below
    packages = with pkgs; [
      bash-language-server
      delve
      go
      gopls
      luaformatter
      luajit
      lua-language-server
      mcp-nixos
      nil
      nixfmt-rfc-style
      prettier
      nodejs_24
      python3
      uv
      shellcheck
      shfmt
      stylua
      svelte-check
      svelte-language-server
      tsx
      typescript
      typescript-language-server
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
          "[svelte]"."editor.defaultFormatter" = "svelte.svelte-vscode";
          "[xml]"."editor.defaultFormatter" = "DotJoshJohnson.xml";
          "files.insertFinalNewline" = true;
          "files.trimTrailingWhitespace" = true;
          "git.openRepositoryInParentFolders" = "always";
          "github.copilot.chat.agent.thinkingTool" = true;
          "github.copilot.chat.codesearch.enabled" = true;
          "githubPullRequests.pullBranch" = "never";
          "gopls.ui.semanticTokens" = true;
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
          "svelte.enable-ts-plugin" = true;
          "svelte.language-server.ls-path" = "${pkgs.svelte-language-server}/bin/svelte-language-server";
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

            Write a conventional commit message summarising the final outcome of what we've just been working on, focus on the staged changes in the git repository if there are any.

            Please create a commit message that:
            - Follows Conventional Commits 1.0.0 specification exactly
            - Uses appropriate type (feat, fix, build, chore, ci, docs, perf, refactor, etc.)
            - Includes proper scope if applicable
            - Has clear, imperative mood description under 72 characters
            - Includes body with bullet points if needed
            - Adds footers for breaking changes or issue references if relevant

            Output only the commit message, ready for `git commit -m`.
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
            vscode-marketplace.nhoizey.gremlins
            vscode-marketplace.nico-castell.linux-desktop-file
            vscode-marketplace.pixelbyte-studios.pixelbyte-love2d
            vscode-marketplace.pkief.material-product-icons
            vscode-marketplace.prince781.vala
            vscode-marketplace.pollywoggames.pico8-ls
            vscode-marketplace.redhat.vscode-yaml
            vscode-marketplace.rogalmic.bash-debug
            vscode-marketplace.rust-lang.rust-analyzer
            vscode-marketplace.ryu1kn.partial-diff
            vscode-marketplace.sanjulaganepola.github-local-actions
            vscode-marketplace.slevesque.shader
            vscode-marketplace.streetsidesoftware.code-spell-checker
            vscode-marketplace.svelte.svelte-vscode
            vscode-marketplace.tamasfe.even-better-toml
            vscode-marketplace.timonwong.shellcheck
            vscode-marketplace.trond-snekvik.simple-rst
            vscode-marketplace.twxs.cmake
            vscode-marketplace.tobiashochguertel.just-formatter
            vscode-marketplace.unifiedjs.vscode-mdx
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
  };
  services.vscode-server.enable = true;
}
