{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;
  system = pkgs.stdenv.hostPlatform.system;
  concordPackage = inputs.concord.packages.${system}.default.override {
    stdenv = pkgs.unstable.stdenv // {
      isLinux = pkgs.unstable.stdenv.hostPlatform.isLinux;
    };
  };
in
{
  config = lib.mkIf (host.is.linux && host.is.workstation && system == "x86_64-linux") {
    home.packages = [
      concordPackage
    ];
  };
}
