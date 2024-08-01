{
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
  # Jopin CLI fails to build on x86_64-darwin
  home = {
    packages = with pkgs; [
      font-awesome_5
    ] ++ lib.optionals (platform != "x86_64-darwin") [
      joplin
    ];
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
