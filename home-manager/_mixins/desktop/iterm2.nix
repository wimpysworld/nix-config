{ lib, pkgs, ... }:
let
  inherit (pkgs.stdenv) isDarwin;
in
lib.mkIf isDarwin {
  home.packages = with pkgs; [
    iterm2
  ];
  targets.darwin.defaults = {
    "com.googlecode.iterm2" = {
      AddNewTabAtEndOfTabs = true;
      CopySelection = true;
    };
  };
}
