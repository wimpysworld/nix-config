{
  config,
  lib,
  pkgs,
  ...
}:
{
  claude-code.lspServers.dart = {
    command = "${pkgs.dart}/bin/dart";
    args = [ "language-server" ];
    extensionToLanguage = {
      ".dart" = "dart";
    };
  };

  home = {
    packages = with pkgs; [
      # lowPrio to avoid bin/resources collision with pkgs.resources (GNOME system monitor)
      # Dart SDK ships bin/resources/ as an internal directory; dart tools resolve it via store path
      (lib.lowPrio dart)
    ];
  };

  programs = {
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
