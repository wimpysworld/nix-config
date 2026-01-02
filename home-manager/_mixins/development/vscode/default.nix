{
  config,
  inputs,
  isWorkstation,
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
lib.mkIf (lib.elem username installFor && isWorkstation) {
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
      lldb
      nodejs_24
      prettier
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
          "editor.bracketPairColorization.independentColorPoolPerBracketType" = true;
          "editor.fontSize" = 16;
          "editor.fontFamily" = "FiraCode Nerd Font Mono";
          "editor.fontLigatures" = true;
          "editor.fontWeight" = "400";
          "editor.formatOnPaste" = true;
          "editor.formatOnSave" = true;
          "editor.guides.bracketPairs" = true;
          "editor.guides.bracketPairsHorizontal" = true;
          "editor.inlineSuggest.enabled" = true;
          "editor.insertSpaces" = true;
          "editor.renderWhitespace" = "all";
          "editor.rulers" = [
            80
            88
          ];
          "editor.semanticHighlighting.enabled" = true;
          "editor.tabSize" = 2;
          "editor.wordWrap" = "on";
          "explorer.confirmDragAndDrop" = false;
          "extensions.ignoreRecommendations" = true;
          "[dockerfile]"."editor.quickSuggestions.strings" = true;
          "[xml]"."editor.defaultFormatter" = "DotJoshJohnson.xml";
          "files.insertFinalNewline" = true;
          "files.trimTrailingWhitespace" = true;
          "github.copilot.chat.agent.thinkingTool" = true;
          "github.copilot.chat.codesearch.enabled" = true;
          "githubPullRequests.pullBranch" = "never";
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
          "security.workspace.trust.untrustedFiles" = "open";
          "telemetry.feedback.enabled" = false;
          "telemetry.telemetryLevel" = "off";
          "terminal.integrated.fontSize" = 16;
          "terminal.integrated.fontFamily" = "FiraCode Nerd Font Mono";
          "terminal.integrated.fontWeight" = 400;
          "terminal.integrated.fontWeightBold" = 600;
          "terminal.integrated.scrollback" = 16384;
          "terminal.integrated.copyOnSelection" = true;
          "terminal.integrated.cursorBlinking" = true;
          "update.mode" = "none";
          "window.controlsStyle" =
            if config.wayland.windowManager.hyprland.enable then "hidden" else "native";
          "workbench.colorTheme" = "Catppuccin Mocha";
          "workbench.editor.empty.hint" = "hidden";
          "workbench.iconTheme" = "catppuccin-mocha";
          "workbench.tree.indent" = 20;
          "workbench.startupEditor" = "none";
        };
        extensions =
          with pkgs;
          [
            vscode-marketplace.alefragnani.project-manager
            vscode-marketplace.catppuccin.catppuccin-vsc-icons
            vscode-marketplace.coolbear.systemd-unit-file
            vscode-marketplace.dotjoshjohnson.xml
            vscode-marketplace.editorconfig.editorconfig
            vscode-marketplace.esbenp.prettier-vscode
            vscode-marketplace.fill-labs.dependi
            vscode-marketplace.github.copilot
            vscode-marketplace.github.copilot-chat
            vscode-marketplace.github.vscode-github-actions
            vscode-marketplace.github.vscode-pull-request-github
            vscode-marketplace.griimick.vhs
            vscode-marketplace.gruntfuggly.todo-tree
            vscode-marketplace.jdemille.debian-control-vscode
            vscode-marketplace.jeff-hykin.better-csv-syntax
            vscode-marketplace.jeff-hykin.better-dockerfile-syntax
            vscode-marketplace.jeff-hykin.polacode-2019
            vscode-marketplace.mechatroner.rainbow-csv
            vscode-marketplace.ms-vscode.cmake-tools
            vscode-extensions.ms-vscode-remote.vscode-remote-extensionpack
            vscode-marketplace.nhoizey.gremlins
            vscode-marketplace.nico-castell.linux-desktop-file
            vscode-marketplace.ryu1kn.partial-diff
            vscode-marketplace.sanjulaganepola.github-local-actions
            vscode-marketplace.streetsidesoftware.code-spell-checker
            vscode-marketplace.twxs.cmake
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
