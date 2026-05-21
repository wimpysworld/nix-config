{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;
  inherit (pkgs.stdenv.hostPlatform) system;
in
lib.mkIf host.is.workstation {
  home.packages = [
    inputs.fresh.packages.${system}.fresh
  ];
}
