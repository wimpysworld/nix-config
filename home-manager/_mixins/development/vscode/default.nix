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
  installFor = [ "none" ];
  inherit (pkgs.stdenv) isLinux;
in
lib.mkIf (lib.elem username installFor && isWorkstation) {
  nixpkgs.overlays = [
    inputs.nix-vscode-extensions.overlays.default
  ];

  catppuccin = {
    vscode.profiles.default.enable = config.programs.vscode.enable;
    vscode.profiles.default.icons.enable = config.programs.vscode.enable;
  };

  programs = {
    vscode = {
      enable = true;
      profiles.default = {
        enableExtensionUpdateCheck = false;
        enableUpdateCheck = false;
        userSettings = {
          "catppuccin-icons.hidesExplorerArrows" = false; # Set to `true` to disable folding arrows next to folder icons.
          "catppuccin-icons.specificFolders" = true; # Set to `false` to only use the default folder icon.
          "catppuccin-icons.monochrome" = false; # Set to `true` to only use the `text` fill color for all icons.
          "cSpell.diagnosticLevel" = "Hint";
          "editor.bracketPairColorization.independentColorPoolPerBracketType" = true;
          "editor.cursorBlinking" = "smooth";
          "editor.cursorSmoothCaretAnimation" = "on";
          "editor.cursorStyle" = "block";
          "editor.fontSize" = 16;
          "editor.fontFamily" = "FiraCode Nerd Font Mono";
          "editor.fontLigatures" = true;
          "editor.fontWeight" = 400;
          "editor.formatOnPaste" = true;
          "editor.formatOnSave" = true;
          "editor.guides.bracketPairs" = true;
          "editor.guides.bracketPairsHorizontal" = true;
          "editor.guides.highlightActiveBracketPair" = true;
          "editor.indentSize" = 2;
          "editor.inlineSuggest.enabled" = true;
          "editor.insertSpaces" = true;
          "editor.renderWhitespace" = "all";
          "editor.rulers" = [
            80
            88
          ];
          "editor.semanticHighlighting.enabled" = true;
          "editor.smoothScrolling" = true;
          "editor.tabSize" = 2;
          "editor.wordWrap" = "on";
          "[xml]"."editor.defaultFormatter" = "DotJoshJohnson.xml";
          "explorer.confirmDragAndDrop" = false;
          "extensions.ignoreRecommendations" = true;
          "files.insertFinalNewline" = true;
          "files.trimTrailingWhitespace" = true;
          "partialDiff.enableTelemetry" = false;
          "security.workspace.trust.untrustedFiles" = "open";
          "semgrep.path" = "${pkgs.semgrep}/bin/semgrep";
          "telemetry.editStats.enabled" = false;
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
          "workbench.editor.empty.hint" = "hidden";
          "workbench.tree.indent" = 20;
          "workbench.list.smoothScrolling" = true;
          "workbench.startupEditor" = "none";
        };
        extensions =
          with pkgs;
          [
            vscode-marketplace.coolbear.systemd-unit-file
            vscode-marketplace.dotjoshjohnson.xml
            vscode-marketplace.editorconfig.editorconfig
            vscode-marketplace.fill-labs.dependi
            vscode-marketplace.griimick.vhs
            vscode-marketplace.gruntfuggly.todo-tree
            vscode-marketplace.jdemille.debian-control-vscode
            vscode-marketplace.jeff-hykin.better-csv-syntax
            vscode-marketplace.jeff-hykin.better-dockerfile-syntax
            vscode-marketplace.jeff-hykin.polacode-2019
            vscode-marketplace.mechatroner.rainbow-csv
            vscode-extensions.ms-vscode-remote.vscode-remote-extensionpack
            vscode-marketplace.nhoizey.gremlins
            vscode-marketplace.nico-castell.linux-desktop-file
            vscode-marketplace.ryu1kn.partial-diff
            vscode-marketplace.semgrep.semgrep
            vscode-marketplace.streetsidesoftware.code-spell-checker
          ]
          ++ lib.optionals isLinux [
            vscode-extensions.ms-vsliveshare.vsliveshare
          ];
      };
      mutableExtensionsDir = true;
      package = pkgs.unstable.vscode;
    };
  };
  services.vscode-server.enable = true;
}
