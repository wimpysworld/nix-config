{
  config,
  hostname,
  lib,
  pkgs,
  ...
}:
let
  installOn = [
    "phasma"
    "vader"
  ];
in
lib.mkIf (lib.elem hostname installOn) {
  home = {
    packages = with pkgs; [
      love
      luaformatter
      luajit
      lua-language-server
      stylua
    ];
  };
  programs = {
    vscode = lib.mkIf config.programs.vscode.enable {
      profiles.default = {
        userSettings = {
          "[lua]"."editor.defaultFormatter" = "JohnnyMorganz.stylua";
        };
        extensions = with pkgs; [
          vscode-marketplace.ismoh-games.second-local-lua-debugger-vscode
          vscode-marketplace.johnnymorganz.stylua
          vscode-marketplace.pixelbyte-studios.pixelbyte-love2d
          vscode-marketplace.yinfei.luahelper
        ];
      };
    };
  };
}
