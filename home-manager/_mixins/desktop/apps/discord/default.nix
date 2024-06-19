{ lib, pkgs, username, ... }:
let
  inherit (pkgs.stdenv) isDarwin isLinux;
in
{
  imports = lib.optional (builtins.pathExists (./. + "/${username}.nix")) ./${username}.nix;

  home = {
    packages = with pkgs; [
      betterdiscordctl
      discord
    ];
  };

  # discocss is currently broken; including the proposed fix
  # - https://github.com/mlvzk/discocss/pull/28
  #programs.discocss = {
  #  enable = true;
  #  css = ''
  #    @import url("https://catppuccin.github.io/discord/dist/catppuccin-mocha.theme.css");
  #    @import url("https://catppuccin.github.io/discord/dist/catppuccin-mocha-blue.theme.css");
  #  '';
  #};
}
