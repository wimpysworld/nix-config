{
  config,
  lib,
  noughtyLib,
  ...
}:
let
  isNixosUser = noughtyLib.isUser [ "nixos" ];
in
{
  config = lib.mkIf isNixosUser {
    users.users.nixos.description = "NixOS";

    # All configurations for live media are below:
    system = lib.mkIf config.noughty.host.is.iso {
      stateVersion = lib.mkForce lib.trivial.release;
    };
  };
}
