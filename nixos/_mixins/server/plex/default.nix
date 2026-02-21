{
  lib,
  noughtyLib,
  ...
}:
lib.mkIf (noughtyLib.isHost [ "revan" ]) {
  services = {
    plex = {
      enable = true;
      dataDir = "/srv/state/plex";
      openFirewall = true;
    };
  };
}
