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

  fresh.settings.lsp.dart = {
    command = "${pkgs.dart}/bin/dart";
    args = [
      "language-server"
      "--protocol=lsp"
    ];
    enabled = true;
    auto_start = true;
    initialization_options.lineLength = 80;
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
  };
}
