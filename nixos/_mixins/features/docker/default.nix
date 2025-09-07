{
  config,
  lib,
  pkgs,
  username,
  ...
}:
let
  installFor = [ "martin" ];
  hasNvidiaGPU = lib.elem "nvidia" config.services.xserver.videoDrivers;
  rootlessMode = false;
in
lib.mkIf (lib.elem "${username}" installFor) {
  # https://wiki.nixos.org/wiki/Docker
  environment = {
    systemPackages = with pkgs; [
      act
      distrobox
      docker-color-output
      docker-compose
      docker-init
      docker-sbom
      fuse-overlayfs
      lazydocker
    ];
  };
  # TODO: Add docker-desktop https://github.com/NixOS/nixpkgs/issues/228972

  hardware.nvidia-container-toolkit.enable = hasNvidiaGPU;

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
  };

  users.users.${username} = {
    extraGroups = lib.optional config.virtualisation.docker.enable "docker";
  };
}
