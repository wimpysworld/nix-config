{ config, desktop, lib, pkgs, ... }: {
  #https://nixos.wiki/wiki/Podman
  environment.systemPackages = with pkgs; [
    unstable.distrobox
    fuse-overlayfs
    podman-compose
  ] ++ lib.optionals (desktop != null) [
    unstable.pods
    unstable.quickemu
    xorg.xhost
  ];

  virtualisation = {
    podman = {
      defaultNetwork.settings = {
        dns_enabled = true;
      };
      dockerCompat = true;
      enable = true;
      enableNvidia = lib.elem "nvidia" config.services.xserver.videoDrivers;
    };
  };
}
