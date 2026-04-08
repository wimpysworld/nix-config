{
  inputs,
  ...
}:
{
  imports = [
    inputs.nixos-hardware.nixosModules.lenovo-thinkpad-z13-gen1
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
