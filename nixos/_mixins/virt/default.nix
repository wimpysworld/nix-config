{ config, desktop, lib, pkgs, ... }: {
  #https://nixos.wiki/wiki/Podman
  environment.systemPackages = with pkgs; [
    distrobox
    flyctl
    fuse-overlayfs
    podman-compose
    podman-tui
    podman
  ] ++ lib.optionals (desktop != null) [
    pods
    quickemu
    xorg.xhost
  ];

  virtualisation = {
    lxd = {
      enable = true;
    };
    podman = {
      defaultNetwork.settings = {
        dns_enabled = true;
      };
      dockerCompat = true;
      dockerSocket.enable = true;
      enable = true;
      enableNvidia = lib.elem "nvidia" config.services.xserver.videoDrivers;
    };
  };
  
  networking = {
    firewall = {
      trustedInterfaces = [ "lxdbr0" ];
    };
  };
}
