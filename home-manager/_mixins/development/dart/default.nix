{
  config,
  lib,
  pkgs,
  ...
}:
{
  home = {
    packages = with pkgs; [
      dart
    ];
  };

  programs = {
    vscode = lib.mkIf config.programs.vscode.enable {
      profiles.default = {
        userSettings = {
          "dart.updateDevTools" = false;
          "dart.checkForSdkUpdates" = false;
          "[dart]"."editor.formatOnSave" = true;
          "[dart]"."editor.formatOnType" = true;
          "[dart]"."editor.rulers" = [ 80 ];
          "[dart]"."editor.selectionHighlight" = false;
          "[dart]"."editor.suggest.snippetsPreventQuickSuggestions" = false;
          "[dart]"."editor.suggestSelection" = "first";
          "[dart]"."editor.tabCompletion" = "onlySnippets";
          "[dart]"."editor.wordBasedSuggestions" = "off";
        };
        extensions = with pkgs; [
          vscode-marketplace.dart-code.dart-code
          vscode-marketplace.dart-code.flutter
          vscode-marketplace.jeroen-meijer.pubspec-assist
        ];
      };
    };
    zed-editor = lib.mkIf config.programs.zed-editor.enable {
      extensions = [
        "dart"
      ];
      userSettings = {
        # Dart language-specific settings
        languages = {
          Dart = {
            format_on_save = "off";
            tab_size = 2;
          };
        };
        # Dart LSP configuration for formatting line length
        lsp = {
          dart = {
            settings = {
              lineLength = 80;
            };
          };
        };
      };
    };
    neovim = lib.mkIf config.programs.neovim.enable {
      plugins = [
        (pkgs.vimPlugins.nvim-treesitter.withPlugins (p: [
          p.dart
        ]))
      ];
      extraLuaConfig = ''
        -- Dart LSP using Neovim 0.11+ native API
        vim.lsp.enable('dartls')
        -- Dart formatting with dart format
        require('conform').formatters_by_ft.dart = { 'dart_format' }
      '';
    };
  };
}
