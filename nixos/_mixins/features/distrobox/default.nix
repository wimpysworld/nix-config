{ config, desktop, lib, pkgs, username, ... }:
let
  installFor = [ "martin" ];
  isWorkstation = if (desktop != null) then true else false;
  hasNvidiaGPU = lib.elem "nvidia" config.services.xserver.videoDrivers;
in
lib.mkIf (lib.elem "${username}" installFor) {
  #https://nixos.wiki/wiki/Podman
  environment = {
    systemPackages = (with pkgs; [
      distrobox
      fuse-overlayfs
    ] ++ lib.optionals (isWorkstation) [
      pods
    ]);
  };

  hardware.nvidia-container-toolkit.enable = hasNvidiaGPU;

  virtualisation =  {
    podman = {
      defaultNetwork.settings = {
        dns_enabled = true;
      };
      dockerCompat = true;
      dockerSocket.enable = true;
      enable = true;
    };
  };

  users.users.${username}.extraGroups = lib.optional (config.virtualisation.podman.enable) "podman";
}
