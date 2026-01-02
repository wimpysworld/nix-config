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
    clang-tools
    neocmakelsp
    vscode-css-languageserver
  ];
  programs = {
    zed-editor = {
      enable = true;
      extensions = [
        "comment"
        "desktop"
        "dockerfile"
        "editorconfig"
        "github-actions"
        "ini"
        "make"
        "neocmake"
        "rainbow-csv"
        "vhs"
        "xml"
      ];
      package = pkgs.unstable.zed-editor;
      userSettings = {
        telemetry = {
          metrics = false;
          diagnostics = false;
        };
      };
    };
  };
}
