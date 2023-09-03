# Intel Skull Canyon NUC6i7KYK
{ inputs, lib, ... }:
{
  imports = [
    inputs.nixos-hardware.nixosModules.common-cpu-intel
    inputs.nixos-hardware.nixosModules.common-gpu-intel
    inputs.nixos-hardware.nixosModules.common-pc
    inputs.nixos-hardware.nixosModules.common-pc-ssd
    (import ./disks.nix { })
    ../_mixins/hardware/systemd-boot.nix
    ../_mixins/services/bluetooth.nix
    ../_mixins/services/maestral.nix
    ../_mixins/services/zerotier.nix
    ../_mixins/virt
  ];

  # Workaround WRITE FPDMA QUEUED errors
  # - Set link_power_management_policy to max_performance
  # - Set SATA link speed to 3.0Gbps
  # - https://serverfault.com/questions/400338/how-to-reduce-the-sata-link-speed-of-drive-in-centos
  boot.kernelParams = [ "ahci.mobile_lpm_policy=0" "libata.force=3.0G" ];
  # The above seems to work, but other workaround include disabling NCQ and NCQ Trim via "libata.force=3.0G,noncq,noncqtrim"
  # - https://bugzilla.kernel.org/show_bug.cgi?id=203475#c14

  # disko does manage mounting of / /boot /home, but I want to mount by-partlabel
  fileSystems."/" = lib.mkForce {
    device = "/dev/disk/by-partlabel/root";
    fsType = "xfs";
    options = [ "defaults" "relatime" "nodiratime" ];
  };

  fileSystems."/boot" = lib.mkForce {
    device = "/dev/disk/by-partlabel/ESP";
    fsType = "vfat";
  };

  fileSystems."/home" = lib.mkForce {
    device = "/dev/disk/by-partlabel/home";
    fsType = "xfs";
    options = [ "defaults" "relatime" "nodiratime" ];
  };

  fileSystems."/mnt/fours" = lib.mkForce {
    device = "/dev/md/fours1";
    fsType = "xfs";
    options = [ "defaults" "relatime" "nodiratime" ];
  };

  fileSystems."/mnt/twos" = lib.mkForce {
    device = "/dev/md/twos1";
    fsType = "xfs";
    options = [ "defaults" "relatime" "nodiratime" ];
  };

  swapDevices = [{
    device = "/swap";
    size = 2048;
  }];

  boot = {
    initrd.availableKernelModules = [ "xhci_pci" "nvme" "usbhid" "uas" "sd_mod" ];
    kernelModules = [ "kvm-intel" ];
  };

  # Use passed hostname to configure basic networking
  networking = {
    defaultGateway = "192.168.2.1";
    # ZeroTier routing
    # - https://chrisatech.wordpress.com/2021/02/22/routing-traffic-to-zerotiers-subnet-from-all-devices-on-the-lan/
    # - https://harivemula.com/2021/09/18/routing-all-traffic-through-home-with-zerotier-on-travel/
    firewall.extraCommands = "
    iptables -t nat -A POSTROUTING -o eno1 -j MASQUERADE
    iptables -A FORWARD -i eno1 -o ztwfukvgqh -m state --state RELATED,ESTABLISHED -j ACCEPT
    iptables -A FORWARD -i ztwfukvgqh -o eno1 -j ACCEPT
    ";
    interfaces.eno1.mtu = 1462;
    interfaces.eno1.ipv4.addresses = [{
      address = "192.168.2.17";
      prefixLength = 24;
    }];
    nameservers = [ "127.0.0.1" ];
    useDHCP = lib.mkForce false;
  };

  # Home LAN DNS server
  # - https://l33tsource.com/blog/2023/06/18/dnsmasq-on-NixOS-2305/
  services.dnsmasq = {
    enable = true;
    alwaysKeepRunning = true;
    # Use AdGuard Public DNS with family protection filters
    # - https://adguard-dns.io/en/public-dns.html
    settings.server = [ "94.140.14.15" "94.140.15.16"];
    settings = { cache-size=500; };
  };

  services.hardware.bolt.enable = true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
