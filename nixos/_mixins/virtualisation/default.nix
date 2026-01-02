{
  config,
  isWorkstation,
  lib,
  pkgs,
  username,
  ...
}:
let
  hasNvidiaGPU = lib.elem "nvidia" config.services.xserver.videoDrivers;
  installFor = [ "martin" ];
  rootlessMode = false;
in
lib.mkIf (lib.elem "${username}" installFor && isWorkstation) {
  environment = {
    # https://wiki.nixos.org/wiki/Docker
    systemPackages = with pkgs; [
      act
      distrobox
      docker-color-output
      docker-compose
      docker-init
      docker-sbom
      fuse-overlayfs
      lazydocker
      qemu
      quickemu
    ];
  };

  hardware.nvidia-container-toolkit.enable = hasNvidiaGPU;

  users.users.${username} = {
    extraGroups = lib.optional config.virtualisation.docker.enable "docker";
  };

  virtualisation = {
    containers.enable = true;
    docker = {
      enable = true;
      rootless = lib.mkIf rootlessMode {
        enable = rootlessMode;
        setSocketVariable = rootlessMode;
      };
    };
    oci-containers.backend = "docker";
    spiceUSBRedirection.enable = true;
  };
}
