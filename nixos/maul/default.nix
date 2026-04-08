{
  inputs,
  lib,
  pkgs,
  ...
}:
{
  imports = [
    inputs.nixos-hardware.nixosModules.common-cpu-amd
    inputs.nixos-hardware.nixosModules.common-gpu-nvidia
    inputs.nixos-hardware.nixosModules.common-pc
    inputs.nixos-hardware.nixosModules.common-pc-ssd
    ./disks.nix
  ];

  boot = {
    initrd = {
      availableKernelModules = [ "thunderbolt" ];
      kernelModules = [
        "kvm-amd"
        "nvidia"
      ];
    };
    kernelPackages = lib.mkForce pkgs.linuxPackages_6_12;
  };

  hardware = {
    nvidia = {
      open = false;
      prime.offload.enable = false;
    };
  };

  services = {
    xserver.videoDrivers = [
      "nvidia"
    ];
  };
}
