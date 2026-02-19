{
  config,
  lib,
  noughtyLib,
  ...
}:
lib.mkIf (noughtyLib.isHost [ "vader" ]) {
  networking.networkmanager = lib.mkIf config.networking.networkmanager.enable {
    # Adjust MTU for Virgin Fibre
    connectionConfig = {
      "ethernet.mtu" = 1462;
      "wifi.mtu" = 1462;
    };
    # Disable WiFi power saving
    wifi.powersave = true;
  };
}
