{ config, hostname, lib, pkgs, ... }: {
  imports = lib.optional (builtins.pathExists (./. + "/${hostname}.nix")) ./${hostname}.nix;
  # Add allowedNetworks="192.168.2.0/255.255.255.0" to /srv/pool/state/plex/Plex\ Media\ Server/Preferences.xml
  # https://www.jjpdev.com/posts/plex-media-server-tailscale/
  services.plex = {
    enable = true;
    dataDir = "/srv/state/plex";
    openFirewall = true;
  };
}
