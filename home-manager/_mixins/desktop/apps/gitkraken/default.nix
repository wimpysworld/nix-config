{ config, lib, pkgs, username, ... }:
let
  inherit (pkgs.stdenv) isDarwin isLinux;
in
{
  imports = lib.optional (builtins.pathExists (./. + "/${username}.nix")) ./${username}.nix;

  home = {
    file = {
      # https://github.com/davi19/gitkraken
      "${config.home.homeDirectory}/.gitkraken/themes/catppuccin_mocha.jsonc".text = builtins.readFile ./gitkraken-catppuccin-mocha-blue.json;
    };
    packages = with pkgs; [
      gitkraken
    ];
  };
}
