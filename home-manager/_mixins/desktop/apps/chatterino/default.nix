{ config, lib, pkgs, username, ... }:
let
  inherit (pkgs.stdenv) isDarwin isLinux;
in
{
  imports = lib.optional (builtins.pathExists (./. + "/${username}.nix")) ./${username}.nix;

  home = {
    file = {
      "${config.home.homeDirectory}/.local/share/chatterino/Themes/mocha-blue.json".text = builtins.readFile ./chatterino-mocha-blue.json;
    };
    packages = with pkgs; [
      chatterino2
    ];
  };
}
