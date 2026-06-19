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
in
{
  config = lib.mkIf (host.is.linux && system == "x86_64-linux") {
    home.packages = [
      inputs.concord.packages.${system}.default
    ];
  };
}
