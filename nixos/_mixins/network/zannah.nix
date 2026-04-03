{
  config,
  lib,
  noughtyLib,
  ...
}:
lib.mkIf (noughtyLib.isHost [ "zannah" ]) {
  networking.networkmanager = lib.mkIf config.networking.networkmanager.enable {
    ensureProfiles.profiles = {
      "enp191s0" = {
        connection = {
          id = "enp191s0";
          type = "ethernet";
          interface-name = "enp191s0";
        };
        ipv4 = {
          ignore-auto-dns = "true";
        };
        ipv6 = {
          ignore-auto-dns = "true";
        };
      };
    };
  };
}
