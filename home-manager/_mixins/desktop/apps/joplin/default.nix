{
  config,
  lib,
  pkgs,
  platform,
  username,
  ...
}:
let
  installFor = [ "martin" ];
  inherit (pkgs.stdenv) isLinux;
in
lib.mkIf (lib.elem username installFor) {
  home = {
    file = {
      # Customised Catppuccin Mocha Blue theme for Joplin
      # - https://github.com/catppuccin/joplin
      # - https://joplinapp.org/help/apps/custom_css
      "${config.home.homeDirectory}/.config/joplin-desktop/userchrome.css".text = builtins.readFile ./userchrome.css;
      "${config.home.homeDirectory}/.config/joplin-desktop/userstyle.css".text = builtins.readFile ./userstyle.css;
    };
  };

  programs.joplin-desktop = {
    enable = isLinux;
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
