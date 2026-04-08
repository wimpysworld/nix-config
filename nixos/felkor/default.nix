{
  inputs,
  ...
}:
{
  imports = [
    inputs.nixos-hardware.nixosModules.lenovo-thinkpad-x13-amd
    ./disks.nix
  ];

  boot = {
    initrd.availableKernelModules = [
      "thunderbolt"
    ];
    initrd.systemd.enable = true;
    kernelModules = [
      "amdgpu"
      "kvm-amd"
    ];
  };
}
