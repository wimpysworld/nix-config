{
  config,
  lib,
  noughtyLib,
  ...
}:
lib.mkIf (noughtyLib.isHost [ "phasma" ]) {
  # Disable WiFi power saving
  networking.networkmanager = lib.mkIf config.networking.networkmanager.enable {
    wifi.powersave = true;
  };
}
