{
  config,
  inputs,
  lib,
  pkgs,
  username,
  ...
}:
{
  imports = [
    inputs.nixos-hardware.nixosModules.common-cpu-amd
    inputs.nixos-hardware.nixosModules.common-gpu-amd
    inputs.nixos-hardware.nixosModules.common-gpu-nvidia
    inputs.nixos-hardware.nixosModules.common-pc
    inputs.nixos-hardware.nixosModules.common-pc-ssd
    ./disks.nix
    ./disks-home.nix
    ./disks-snapshot.nix
  ];

  # TODO: Remove this if/when machine is reinstalled.
  # This is a workaround for the legacy -> gpt tables disko format.
  fileSystems = {
    "/".device = lib.mkForce "/dev/disk/by-partlabel/root";
    "/boot".device = lib.mkForce "/dev/disk/by-partlabel/ESP";
  };

  boot = {
    initrd.availableKernelModules = [
      "nvme"
      "ahci"
      "xhci_pci"
      "usbhid"
      "uas"
      "sd_mod"
    ];
    kernelModules = [
      "amdgpu"
      "kvm-amd"
      "nvidia"
    ];
    kernelParams = [
      "video=DP-1:2560x2880@60"
      "video=DP-2:2560x2880@60"
      "video=DP-3:1920x1080@60"
    ];
    swraid = {
      enable = true;
      mdadmConf = "MAILADDR=${username}@wimpys.world";
    };
  };

  hardware = {
    mwProCapture.enable = true;
    nvidia = {
      #package = config.boot.kernelPackages.nvidiaPackages.latest;
      #package = config.boot.kernelPackages.nvidiaPackages.mkDriver {
      #  version = "570.144";
      #  sha256_64bit = "sha256-wLjX7PLiC4N2dnS6uP7k0TI9xVWAJ02Ok0Y16JVfO+Y=";
      #  sha256_aarch64 = "sha256-6kk2NLeKvG88QH7/YIrDXW4sgl324ddlAyTybvb0BP0=";
      #  openSha256 = "sha256-PATw6u6JjybD2OodqbKrvKdkkCFQPMNPjrVYnAZhK/E=";
      #  settingsSha256 = "sha256-VcCa3P/v3tDRzDgaY+hLrQSwswvNhsm93anmOhUymvM=";
      #  persistencedSha256 = "sha256-hx4w4NkJ0kN7dkKDiSOsdJxj9+NZwRsZEuhqJ5Rq3nM=";
      #};
      open = false;
      prime = {
        amdgpuBusId = "PCI:33:0:0";
        nvidiaBusId = "PCI:30:0:0";
        offload = {
          enable = true;
          enableOffloadCmd = true;
        };
        # Make the Radeon RX 7900 GRE default; the RTX 2000E Ada Generation is for CUDA/NVENC
        reverseSync.enable = true;
      };
    };
  };

  services = {
    cron = {
      enable = true;
      systemCronJobs = [
        "*/30 * * * * ${username} /home/${username}/Scripts/backup/sync-legoworlds.sh >> /home/${username}/Games/Steam_Backups/legoworlds.log"
        "42 * * * * ${username} /home/${username}/Scripts/backup/sync-hotshotracing.sh >> /home/${username}/Games/Steam_Backups/hotshotracing.log"
      ];
    };
  };
  services.xserver.videoDrivers = [
    "amdgpu"
    "nvidia"
  ];
}
