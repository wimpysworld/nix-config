# Intel Skull Canyon NUC6i7KYK
# - https://github.com/rm-hull/skull-canyon
{ inputs, lib, ... }:
{
  imports = [
    inputs.nixos-hardware.nixosModules.common-cpu-intel
    inputs.nixos-hardware.nixosModules.common-gpu-intel
    inputs.nixos-hardware.nixosModules.common-pc
    inputs.nixos-hardware.nixosModules.common-pc-ssd
    (import ./disks.nix { })
  ];

  # disko does manage mounting of / /boot /home, but I want to mount by-partlabel
  fileSystems."/" = lib.mkForce {
    device = "/dev/disk/by-partlabel/root";
    fsType = "xfs";
    options = [
      "defaults"
      "relatime"
      "nodiratime"
    ];
  };

  fileSystems."/boot" = lib.mkForce {
    device = "/dev/disk/by-partlabel/ESP";
    fsType = "vfat";
  };

  fileSystems."/home" = lib.mkForce {
    device = "/dev/disk/by-partlabel/home";
    fsType = "xfs";
    options = [
      "defaults"
      "relatime"
      "nodiratime"
    ];
  };

  fileSystems."/mnt/sonnet" = lib.mkForce {
    device = "/dev/md/TS4p1";
    fsType = "xfs";
    options = [
      "defaults"
      "relatime"
      "nodiratime"
    ];
  };

  swapDevices = [
    {
      device = "/swap";
      size = 2048;
    }
  ];

  boot = {
    initrd.availableKernelModules = [
      "xhci_pci"
      "nvme"
      "usbhid"
      "uas"
      "sd_mod"
    ];
    kernelModules = [ "kvm-intel" ];
    swraid = {
      enable = true;
      mdadmConf = "PROGRAM=true";
    };
  };

  services = {
    # Home LAN DNS server
    # - https://l33tsource.com/blog/2023/06/18/dnsmasq-on-NixOS-2305/
    dnsmasq = {
      enable = true;
      alwaysKeepRunning = true;
      # Use AdGuard Public DNS with family protection filters
      # - https://adguard-dns.io/en/public-dns.html
      settings.server = [
        "94.140.14.15"
        "94.140.15.16"
      ];
      settings = {
        cache-size = 500;
      };
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
}
