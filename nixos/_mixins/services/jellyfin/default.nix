{ config, hostname, lib, ... }:
let
  installOn = [ "revan" ];
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
