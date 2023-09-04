{ config, desktop, lib, pkgs, ... }: {
  imports = [ ] ++ lib.optional (builtins.isString desktop) ./desktop.nix;

  #https://nixos.wiki/wiki/Podman
  environment.systemPackages = with pkgs; [
    unstable.distrobox
    fuse-overlayfs
    podman-compose
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
