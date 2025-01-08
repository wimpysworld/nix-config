{
  config,
  isWorkstation,
  lib,
  pkgs,
  username,
  ...
}:
let
  installFor = [ "martin" ];
  hasNvidiaGPU = lib.elem "nvidia" config.services.xserver.videoDrivers;
in
lib.mkIf (lib.elem "${username}" installFor) {
  #https://nixos.org/wiki/Podman
  environment = {
    systemPackages =
      with pkgs;
      [
        act
        distrobox
        fuse-overlayfs
        podman-compose
        podman-tui
      ]
      ++ lib.optionals (isWorkstation) [
        podman-desktop
      ];
  };

  hardware.nvidia-container-toolkit.enable = hasNvidiaGPU;

  virtualisation = {
    containers.enable = true;
    oci-containers.backend = "podman";
    podman = {
      defaultNetwork.settings = {
        dns_enabled = true;
      };
      dockerCompat = true;
      dockerSocket.enable = true;
      enable = true;
    };
  };

  users.users.${username}.extraGroups = lib.optional config.virtualisation.podman.enable "podman";
}
