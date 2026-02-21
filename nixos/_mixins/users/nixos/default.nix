{
  config,
  lib,
  noughtyLib,
  ...
}:
let
  inherit (config.noughty) host;
  isNixosUser = noughtyLib.isUser [ "nixos" ];
in
{
  config = lib.mkIf isNixosUser {
    users.users.nixos.description = "NixOS";

    # All configurations for live media are below:
    system = lib.mkIf host.is.iso {
      stateVersion = lib.mkForce lib.trivial.release;
    };
  };
}
