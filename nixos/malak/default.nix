# Motherboard:       Gigabyye B360 HD3P-LM Ultra Durable
# CPU:               Intel i7 8700
# GPU:               Intel UHD Graphics 630
# RAM:               128GB DDR4
# NVME0:             512GB Samsung PM9A1 M.2 SSD NVMe (PCIe 4.0 x4) MZVL2512HCJQ-00B00
# SATA1:             8TB Ultrastar DC HC510 7200RPM (SATA) HUH721008ALE600
# SATA2:             8TB Ultrastar DC HC510 7200RPM (SATA) HUH721008ALE600
{
  config,
  hostname,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  username = config.noughty.user.name;
in
{
  imports = [
    inputs.nixos-hardware.nixosModules.common-cpu-intel
    inputs.nixos-hardware.nixosModules.common-gpu-intel
    inputs.nixos-hardware.nixosModules.common-pc
    inputs.nixos-hardware.nixosModules.common-pc-ssd
    ./disks.nix
    ./disks-data.nix
  ];

  boot = {
    initrd = {
      availableKernelModules = [
        "ahci"
        "nvme"
        "sd_mod"
        "xhci_pci"
        "e1000e"
      ];
      network = {
        enable = true;
        ssh = {
          enable = true;
          hostKeys = [ "/etc/ssh/initrd_ssh_host_ed25519_key" ];
          ignoreEmptyHostKeys = true;
          port = 2222;
        };
      };
    };
    kernelModules = [
      "kvm-intel"
    ];
    kernelPackages = lib.mkForce pkgs.linuxPackages_6_12;
    # Make sure the initrd has the necessary IPv4 configuration
    # - ip=ip-addr:<ignore>:gw-addr:netmask:hostname:interface:autoconf:dns1-addr:dns2-addr
    # - https://www.kernel.org/doc/Documentation/filesystems/nfs/nfsroot.txt
    kernelParams = [
      "ip=116.202.241.253::116.202.241.193:255.255.255.192:${hostname}-initrd:eth0:off:185.12.64.1:185.12.64.2"
    ];
    # Using GRUB because malak has no EFI boot available
    loader = {
      grub.enable = true;
      systemd-boot.enable = lib.mkForce false;
    };
    swraid = {
      enable = true;
      mdadmConf = "MAILADDR=${username}@wimpys.world";
    };
  };

  powerManagement.cpuFreqGovernor = "performance";
}
