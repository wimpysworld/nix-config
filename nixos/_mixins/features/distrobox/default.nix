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
        distrobox
        fuse-overlayfs
      ]
      ++ lib.optionals isWorkstation [
        boxbuddy
        pods
      ];
  };

  hardware.nvidia-container-toolkit.enable = hasNvidiaGPU;

  virtualisation = {
    containers.enable = true;
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
