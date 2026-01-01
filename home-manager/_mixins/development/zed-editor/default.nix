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
  programs = {
    zed-editor = {
      enable = true;
      extensions = [
        "github-actions"
        "lua"
      ];
      package = pkgs.unstable.zed-editor;
      userSettings = {
        # Configure zed here
      };
    };
  };
}
