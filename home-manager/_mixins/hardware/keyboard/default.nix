{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;
in
lib.mkIf (host.is.linux && host.is.workstation) {
  home.packages = [
    inputs.nix-packages.packages.${pkgs.stdenv.hostPlatform.system}.wonkey
  ];
}
