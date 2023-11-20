{ config, desktop, inputs, lib, pkgs, platform, ... }: {
  imports = [
    inputs.nix-snapd.nixosModules.default
  ];

  #https://nixos.wiki/wiki/Podman
  environment.systemPackages = with pkgs; [
    distrobox
    flyctl
    fuse-overlayfs
    podman-compose
    podman-tui
    podman
  ] ++ [
    inputs.crafts-flake.packages.${platform}.snapcraft
  ] ++ lib.optionals (desktop != null) [
    pods
    quickemu
    xorg.xhost
  ];

  services.snap.enable = true;

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
