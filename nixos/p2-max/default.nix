{ inputs, lib, pkgs, ... }:
{
  imports = [
    inputs.nixos-hardware.nixosModules.gpd-p2-max
    (import ./disks.nix { })
    ../_mixins/hardware/systemd-boot.nix
    ../_mixins/services/bluetooth.nix
    ../_mixins/services/pipewire.nix
    ../_mixins/services/zerotier.nix
    ../_mixins/virt
  ];

  swapDevices = [{
    device = "/swap";
    size = 2048;
  }];

  boot = {
    initrd.availableKernelModules = [ "xhci_pci" "nvme" "usbhid" "uas" "sd_mod" ];
    kernelModules = [ "kvm-intel" ];
    kernelPackages = pkgs.linuxPackages_latest;
  };

  # My GPD P2 Max has a US keyboard layout
  console.keyMap = lib.mkForce "us";
  services.kmscon.extraConfig = lib.mkForce ''
    font-size=18
    xkb-layout=us
  '';
  services.xserver.layout = lib.mkForce "us";

  environment.systemPackages = with pkgs; [
    nvtop-amd
  ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
