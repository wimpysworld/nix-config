{
  config,
  lib,
  noughtyLib,
  pkgs,
  ...
}:
lib.mkIf (noughtyLib.isHost [ "skrye" ]) (
  lib.mkIf config.networking.networkmanager.enable {
    networking.networkmanager = {
      # Adjust MTU for Virgin Fibre
      connectionConfig = {
        "ethernet.mtu" = 1462;
      };
      # The home router advertises a Unique Local Address prefix and router
      # advertisement without global IPv6 egress, so enp191s0 must not become the
      # default IPv6 route.
      ensureProfiles.profiles = {
        "enp191s0" = {
          connection = {
            id = "enp191s0";
            type = "ethernet";
            interface-name = "enp191s0";
          };
          ipv6 = {
            never-default = true;
          };
        };
      };
    };

    systemd.services.NetworkManager-ensure-profiles.postStart = ''
      ${pkgs.networkmanager}/bin/nmcli connection up id enp191s0
    '';
  }
)
