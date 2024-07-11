{
  hostname,
  lib,
  ...
}:
{
  imports = lib.optional (builtins.pathExists (./. + "/${hostname}.nix")) ./${hostname}.nix;
  services = {
    jellyfin = {
      enable = true;
      dataDir = "/srv/state/jellyfin";
      openFirewall = true;
    };
  };
}
