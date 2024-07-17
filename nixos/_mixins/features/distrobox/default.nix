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
  #https://nixos.wiki/wiki/Podman
  environment = {
    systemPackages =
      with pkgs;
      [
        distrobox
        fuse-overlayfs
      ]
      ++ lib.optionals isWorkstation [ pods ];
    variables = {
      PODMAN_IGNORE_CGROUPSV1_WARNING = "1";
    };
  };

  hardware.nvidia-container-toolkit.enable = hasNvidiaGPU;

  virtualisation = {
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
