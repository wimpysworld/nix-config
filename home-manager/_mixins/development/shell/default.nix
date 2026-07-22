{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;
in
{
  home = {
    packages =
      with pkgs;
      [
        shellcheck
        shfmt
      ]
      ++ lib.optional (!host.is.server) bash-language-server;
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

  claude-code.lspServers = lib.mkIf (!host.is.server && config.programs.claude-code.enable) {
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

  programs.fresh-editor.settings.lsp.bash = lib.mkIf (!host.is.server) {
    command = lib.getExe pkgs.bash-language-server;
    args = [ "start" ];
    enabled = true;
    auto_start = true;
  };
}
