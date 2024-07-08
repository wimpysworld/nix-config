{ config, desktop, hostname, lib, pkgs, ... }:
let
  isInstall = if (builtins.substring 0 4 hostname != "iso-") then true else false;
  isWorkstation = if (desktop != null) then true else false;
  hasNvidia = lib.elem "nvidia" config.services.xserver.videoDrivers;
in
lib.mkIf (isInstall) {
  #https://nixos.wiki/wiki/Podman
  environment = {
    systemPackages = (with pkgs; [
      distrobox
      fuse-overlayfs
    ] ++ lib.optionals (isWorkstation) [
      pods
    ]);
  };

  virtualisation =  {
    containers.cdi.dynamic.nvidia.enable = hasNvidia;
    podman = {
      defaultNetwork.settings = {
        dns_enabled = true;
      };
      dockerCompat = true;
      dockerSocket.enable = true;
      enable = true;
    };
  };
}
