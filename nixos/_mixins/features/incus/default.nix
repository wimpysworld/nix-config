{
  config,
  lib,
  username,
  ...
}:
let
  installFor = [ "martin" ];
  hasNvidiaGPU = lib.elem "nvidia" config.services.xserver.videoDrivers;
in
lib.mkIf (lib.elem "${username}" installFor) {
  # https://wiki.nixos.org/wiki/Incus
  # - See also: nixos/_mixins/features/network/default.nix
  hardware.nvidia-container-toolkit.enable = hasNvidiaGPU;
  virtualisation = {
    incus = {
      enable = true;
      socketActivation = true;
      ui.enable = true;
    };
  };

  users.users.${username}.extraGroups = lib.optional config.virtualisation.incus.enable "incus-admin";
}
