# Motherboard:       Gigabye Z390 Designare
# CPU:               Intel i9 9900K
# RAM:               64GB DDR4
# NVME:              512GB Corsair Force MP600
# NVME:              1TB Corsair Force MP600
# SATA2:             12TB Ultrastar He12
# SATA3:             12TB Ultrastar He12
# Slot 1 (PCIEX16):  Sedna PCIe Quad M.2 SATA III (6G) SSD Adapter
#                    4x Transcend MTS830S 2TB
# Slot 2 (PCIEX1_1): Sedna PCIe Quad 2.5 Inch SATA III (6G) SSD Adapter
#                    4x Crucial MX500 2TB
# Slot 3 (PCIEX8):   NVIDIA T400
# Slot 4 (PCIEX1_2): Sedna PCIe Dual 2.5 Inch SATA III (6G) SSD Adapter
#                    2x 2TB WD Blue (m.2 SATA adapted to 2.5" SATA)
# Slot 5 (PCIEX4):   Sedna PCIe Quad M.2 SATA III (6G) SSD Adapter
#                    4x Transcend MTS830S 2TB

{ config, inputs, lib, pkgs, platform, ... }:
{
  imports = [
    inputs.nixos-hardware.nixosModules.common-cpu-intel
    inputs.nixos-hardware.nixosModules.common-gpu-nvidia
    inputs.nixos-hardware.nixosModules.common-pc
    inputs.nixos-hardware.nixosModules.common-pc-ssd
    ./disks.nix
    ./disks-home.nix
    ./disks-snapshot.nix
    ../_mixins/services/filesync.nix
    ../_mixins/services/tailscale
  ];

  boot = {
    blacklistedKernelModules = lib.mkDefault [ "nouveau" ];
    initrd.availableKernelModules = [ "ahci" "nvme" "uas" "usbhid" "sd_mod" "xhci_pci" ];
    kernelModules = [ "kvm-intel" "nvidia" ];
    swraid = {
      enable = true;
      mdadmConf = "PROGRAM=true";
    };
  };

  environment.systemPackages = with pkgs; [
    mergerfs
    mergerfs-tools
    snapraid
  ];

  # Use passed hostname to configure basic networking
  networking = {
    defaultGateway = "192.168.2.1";
    firewall = {
      trustedInterfaces = [ "eth0" ];
    };
    interfaces.eth0.mtu = 1462;
    interfaces.eth0.ipv4.addresses = [{
      address = "192.168.2.18";
      prefixLength = 24;
    }];
    useDHCP = lib.mkForce false;
    usePredictableInterfaceNames = false;
  };

  hardware = {
    nvidia = {
      package = lib.mkForce config.boot.kernelPackages.nvidiaPackages.production;
      prime = {
        intelBusId = "PCI:0:2:0";
        nvidiaBusId = "PCI:2:0:0";
        # Make the Intel iGPU default. The NVIDIA T400 is for CUDA/NVENC
        reverseSync.enable = true;
      };
      nvidiaSettings = false;
    };
  };
}
