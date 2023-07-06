{ config, desktop, lib, pkgs, ... }: {
  imports = [ ] ++ lib.optional (builtins.isString desktop) [ ./desktop.nix ];

  #https://nixos.wiki/wiki/Podman
  environment.systemPackages = with pkgs; [
    #buildah          # Container build tool
    #conmon           # Container monitoring
    distrobox         # Terminal container manager
    #dive             # Container analyzer
    fuse-overlayfs    # Container overlay+shiftfs
    #grype            # Container vulnerability scanner
    podman-compose
    podman-tui
    #skopeo           # Container registry utility
    #syft             # Container SBOM generator
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
