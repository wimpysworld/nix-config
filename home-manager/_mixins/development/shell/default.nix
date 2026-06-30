{
  config,
  lib,
  pkgs,
  ...
}:
{
  home = {
    packages = with pkgs; [
      bash-language-server
      shellcheck
      shfmt
    ];
  };

  programs = {
    zed-editor = lib.mkIf config.programs.zed-editor.enable {
      extensions = [
        "basher"
        "fish"
      ];
      userSettings = {
        languages = {
          "Shell Script" = {
            format_on_save = "off";
            tab_size = 2;
            hard_tabs = false;
          };
        };
      };
    };
  };

  claude-code.lspServers = lib.mkIf config.programs.claude-code.enable {
    bash = {
      command = lib.getExe pkgs.bash-language-server;
      args = [ "start" ];
      extensionToLanguage = {
        ".sh" = "shellscript";
        ".bash" = "shellscript";
        ".zsh" = "shellscript";
      };
    };
  };

  fresh.settings.lsp.bash = {
    command = lib.getExe pkgs.bash-language-server;
    args = [ "start" ];
    enabled = true;
    auto_start = true;
  };
}
