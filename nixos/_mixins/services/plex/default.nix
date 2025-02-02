{ config, lib, ... }:
let
  installOn = [ "revan" ];
in
lib.mkIf (lib.elem config.networking.hostName installOn) {
  services = {
    plex = {
      enable = true;
      dataDir = "/srv/state/plex";
      openFirewall = true;
    };
  };
}
