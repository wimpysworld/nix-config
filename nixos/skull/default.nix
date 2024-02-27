# Intel Skull Canyon NUC6i7KYK
# - https://github.com/rm-hull/skull-canyon
{ hostname, inputs, lib, platform, username, ... }:
{
  imports = [
    inputs.nixos-hardware.nixosModules.common-cpu-intel
    inputs.nixos-hardware.nixosModules.common-gpu-intel
    inputs.nixos-hardware.nixosModules.common-pc
    inputs.nixos-hardware.nixosModules.common-pc-ssd
    (import ./disks.nix { })
    ../_mixins/hardware/gpu.nix
    ../_mixins/services/filesync.nix
    ../_mixins/services/zerotier.nix
    ../_mixins/virt
  ];

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

  fileSystems."/mnt/sonnet" = lib.mkForce {
    device = "/dev/md/TS4p1";
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
    swraid = {
      enable = true;
      mdadmConf = "PROGRAM=true";
    };
  };

  # Use passed hostname to configure basic networking
  networking = {
    defaultGateway = "192.168.2.1";
    # ZeroTier routing
    # - https://chrisatech.wordpress.com/2021/02/22/routing-traffic-to-zerotiers-subnet-from-all-devices-on-the-lan/
    # - https://harivemula.com/2021/09/18/routing-all-traffic-through-home-with-zerotier-on-travel/
    firewall = {
      extraCommands = "
        iptables -t nat -A POSTROUTING -o eno1 -j MASQUERADE
        iptables -A FORWARD -i eno1 -o ztwfukvgqh -m state --state RELATED,ESTABLISHED -j ACCEPT
        iptables -A FORWARD -i ztwfukvgqh -o eno1 -j ACCEPT
      ";
      trustedInterfaces = [ "eno1" ];
    };
    interfaces.eno1.mtu = 1462;
    interfaces.eno1.ipv4.addresses = [{
      address = "192.168.2.17";
      prefixLength = 24;
    }];
    nameservers = [ "127.0.0.1" ];
    useDHCP = lib.mkForce false;
  };

  services = {
    # Home LAN DNS server
    # - https://l33tsource.com/blog/2023/06/18/dnsmasq-on-NixOS-2305/
    dnsmasq = {
      enable = true;
      alwaysKeepRunning = true;
      # Use AdGuard Public DNS with family protection filters
      # - https://adguard-dns.io/en/public-dns.html
      settings.server = [ "94.140.14.15" "94.140.15.16"];
      settings = { cache-size=500; };
    };
    hardware = {
      bolt.enable = true;
    };
    netdata = {
      enable = true;
      package = pkgs.netdataCloud;
    };
    plex = {
      enable = true;
      dataDir = "/mnt/sonnet/State/plex";
      openFirewall = true;
    };
    prowlarr = {
      enable = true;
      openFirewall = true;
    };
    radarr = {
      enable = true;
      dataDir = "/mnt/sonnet/State/radarr";
      openFirewall = true;
    };
    sonarr = {
      enable = true;
      dataDir = "/mnt/sonnet/State/sonarr";
      openFirewall = true;
    };
    samba = {
      enable = true;
      securityType = "user";
      extraConfig = ''
        workgroup = WIMPRESS.IO
        server string = Skull
        netbios name = Skull
        security = user
        #use sendfile = yes
        #max protocol = smb2
        # note: localhost is the ipv6 localhost ::1
        hosts allow = 192.168.2. 192.168.192. 127.0.0.1 localhost
        hosts deny = 0.0.0.0/0
        guest account = nobody
        map to guest = bad user
      '';
      shares = {
        Films = {
          path = "/mnt/sonnet/Films";
          browseable = "yes";
          "read only" = "no";
          "guest ok" = "yes";
          "create mask" = "0644";
          "directory mask" = "0755";
          "force user" = "$username";
          "force group" = "$username";
        };
        Films_Kids = {
          path = "/mnt/sonnet/Films_Kids";
          browseable = "yes";
          "read only" = "no";
          "guest ok" = "yes";
          "create mask" = "0644";
          "directory mask" = "0755";
          "force user" = "$username";
          "force group" = "$username";
        };
      };
    };
    tautulli = {
      enable = true;
      dataDir = "/mnt/sonnet/State/tautulli";
      openFirewall = true;
    };
  };
  nixpkgs.hostPlatform = lib.mkDefault "${platform}";
}
