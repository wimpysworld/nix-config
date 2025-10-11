{ config, lib, ... }:
{
  # Disable WiFi power saving
  networking.networkmanager = lib.mkIf config.networking.networkmanager.enable {
    wifi.powersave = true;
  };
}
