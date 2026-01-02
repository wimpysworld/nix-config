{
  config,
  isWorkstation,
  lib,
  pkgs,
  username,
  ...
}:
let
  installFor = [ "martin" ];
  inherit (pkgs.stdenv) isLinux;
in
lib.mkIf (lib.elem username installFor && isLinux && isWorkstation) {
  catppuccin.zed.enable = config.programs.zed-editor.enable;
  home.packages = with pkgs; [
    neocmakelsp
  ];
  programs = {
    zed-editor = {
      enable = true;
      extensions = [
        "desktop"
        "dockerfile"
        "github-actions"
        "ini"
        "make"
        "neocmake"
        "rainbow-csv"
        "xml"
      ];
      package = pkgs.unstable.zed-editor;
      userSettings = {
        # Configure zed here
      };
    };
  };
}
