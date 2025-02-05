{ config, hostname, lib, ... }:
let
  installOn = [ ];
in
lib.mkIf (lib.elem config.networking.hostName installOn) {
  services = {
    jellyfin = {
      enable = true;
      dataDir = "/srv/state/jellyfin";
      openFirewall = true;
    };
  };
}
