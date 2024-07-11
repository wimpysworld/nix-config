{
  lib,
  pkgs,
  username,
  ...
}:
let
  installFor = [ "martin" ];
in
lib.mkIf (lib.elem username installFor) {
  home = {
    packages = with pkgs; [
      font-awesome_5
      joplin
    ];
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
