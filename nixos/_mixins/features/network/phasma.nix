{ desktop, lib, pkgs, ... }:
let
  isWorkstation = if (desktop != null) then true else false;
in
lib.mkIf (isWorkstation) {
  # Disable WiFi power saving
  networking.networkmanager.wifi.powersave = true;
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
