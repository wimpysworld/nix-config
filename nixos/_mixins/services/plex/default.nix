{ config, lib, ... }:
let
  installOn = [ "revan" ];
in
lib.mkIf (lib.elem config.networking.hostName installOn) {
  services = {
    # Add allowedNetworks="192.168.2.0/255.255.255.0" to /srv/pool/state/plex/Plex\ Media\ Server/Preferences.xml
    # https://www.jjpdev.com/posts/plex-media-server-tailscale/
    plex = {
      enable = true;
      dataDir = "/srv/state/plex";
      openFirewall = true;
    };
  };
}
