{ desktop, lib, pkgs, ... }:
let
  isWorkstation = if (desktop != null) then true else false;
in
lib.mkIf (isWorkstation) {
  networking.networkmanager = {
    # Adjust MTU for Virgin Fibre
    connectionConfig = {
      "ethernet.mtu" = 1462;
      "wifi.mtu" = 1462;
    };
    # Disable WiFi power saving
    wifi.powersave = true;
  };
  systemd.services = {
    disable-wifi-powersave = {
      wantedBy = ["multi-user.target"];
      path = [ pkgs.iw ];
      script = ''
        iw dev wlan0 set power_save off
      '';
    };
  };
}
