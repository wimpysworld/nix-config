{
  config,
  lib,
  noughtyLib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;
in
lib.mkIf (noughtyLib.isUser [ "martin" ] && host.is.workstation) {
  home = {
    file = {
      # Customised Catppuccin Mocha Blue theme for Joplin
      # - https://github.com/catppuccin/joplin
      # - https://joplinapp.org/help/apps/custom_css
      "${config.xdg.configHome}/joplin-desktop/userchrome.css".text = builtins.readFile ./userchrome.css;
      "${config.xdg.configHome}/joplin-desktop/userstyle.css".text = builtins.readFile ./userstyle.css;
    };
    packages = lib.optionals host.is.workstation [ pkgs.heynote ];
  };

  programs.joplin-desktop = {
    enable = true;
    extraConfig = {
      "markdown.plugin.sub" = true;
      "markdown.plugin.sup" = true;
      "revisionService.ttlDays" = 180;
      "style.editor.fontFamily" = "Work Sans";
      "style.editor.fontSize" = 16;
      "style.editor.monospaceFontFamily" = "FiraCode Nerd Font Mono";
      "theme" = 7;
    };
    sync = {
      interval = "1h";
      target = "dropbox";
    };
  };
}
