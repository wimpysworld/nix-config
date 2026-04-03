{
  config,
  lib,
  noughtyLib,
  ...
}:
lib.mkIf (noughtyLib.isHost [ "skrye" ]) {
  networking.networkmanager = lib.mkIf config.networking.networkmanager.enable {
    # Adjust MTU for Virgin Fibre
    connectionConfig = {
      "ethernet.mtu" = 1462;
    };
  };
}
