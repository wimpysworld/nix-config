{ config, inputs, lib, pkgs, platform, username, ... }:
{
  imports = [
    inputs.nixos-hardware.nixosModules.common-cpu-amd
    inputs.nixos-hardware.nixosModules.common-gpu-amd
    inputs.nixos-hardware.nixosModules.common-gpu-nvidia
    inputs.nixos-hardware.nixosModules.common-pc
    inputs.nixos-hardware.nixosModules.common-pc-ssd
    (import ./disks.nix { })
    (import ./disks-home.nix { })
    (import ./disks-snapshot.nix { })
    ../_mixins/hardware/gpu.nix
    ../_mixins/hardware/systemd-boot.nix
    ../_mixins/hardware/streamdeck.nix
    ../_mixins/services/clamav.nix
    ../_mixins/services/filesync.nix
    ../_mixins/services/openrazer.nix
    ../_mixins/services/pipewire.nix
    ../_mixins/services/tailscale.nix
    ../_mixins/virt
  ];

  # Workaround: manually account for newer disko configuration
  #             REMOVE THIS IF/WHEN /boot and / ARE RE-INSTALLED
  fileSystems = {
    "/" = lib.mkForce {
      device = "/dev/disk/by-partlabel/root";
      fsType = "xfs";
      options = [ "defaults" "relatime" "nodiratime" ];
    };
    "/boot" = lib.mkForce {
      device = "/dev/disk/by-partlabel/ESP";
      fsType = "vfat";
    };
  };

  boot = {
    blacklistedKernelModules = lib.mkDefault [ "nouveau" ];
    initrd.availableKernelModules = [ "nvme" "ahci" "xhci_pci" "usbhid" "uas" "sd_mod" ];
    kernelModules = [ "amdgpu" "kvm-amd" "nvidia" ];
    # Disable USB autosuspend on workstations
    kernelParams = [ "usbcore.autosuspend=-1" ];
    swraid = {
      enable = true;
      mdadmConf = "PROGRAM=true";
    };
  };

  # https://nixos.wiki/wiki/PipeWire
  # https://gitlab.freedesktop.org/pipewire/pipewire/-/wikis/Config-PipeWire#quantum-ranges
  # Debugging
  #  - pw-top                                            # see live stats
  #  - journalctl -b0 --user -u pipewire                 # see logs (spa resync in "bad")
  #  - pw-metadata -n settings 0                         # see current quantums
  #  - pw-metadata -n settings 0 clock.force-quantum 128 # override quantum
  #  - pw-metadata -n settings 0 clock.force-quantum 0   # disable override
  environment.etc = let
    json = pkgs.formats.json {};
  in {
    # Change this to use: services.pipewire.extraConfig.pipewire
    # https://gitlab.freedesktop.org/pipewire/pipewire/-/wikis/Config-PipeWire#quantum-ranges
    "pipewire/pipewire.conf.d/92-low-latency.conf".text = ''
      context.properties = {
        default.clock.rate          = 48000
        default.clock.allowed-rates = [ 48000 ]
        default.clock.quantum       = 64
        default.clock.min-quantum   = 64
        default.clock.max-quantum   = 64
      }
      context.modules = [
        {
          name = libpipewire-module-rt
          args = {
            nice.level = -11
            rt.prio = 88
          }
        }
      ]
    '';
    # Change this to use: services.pipewire.extraConfig.pipewire-pulse
    "pipewire/pipewire-pulse.d/92-low-latency.conf".source = json.generate "92-low-latency.conf" {
      context.modules = [
        {
          name = "libpipewire-module-protocol-pulse";
          args = {
            pulse.min.req     = "64/48000";
            pulse.default.req = "64/48000";
            pulse.max.req     = "64/48000";
            pulse.min.quantum = "64/48000";
            pulse.max.quantum = "64/48000";
          };
        }
      ];
      stream.properties = {
        node.latency = "64/48000";
        resample.quality = 4;
      };
    };
    # https://stackoverflow.com/questions/24040672/the-meaning-of-period-in-alsa
    # https://pipewire.pages.freedesktop.org/wireplumber/daemon/configuration/alsa.html#alsa-buffer-properties
    # https://gitlab.freedesktop.org/pipewire/pipewire/-/issues/3241
    # cat /nix/store/*-wireplumber-*/share/wireplumber/main.lua.d/50-alsa-config.lua
    "wireplumber/main.lua.d/92-low-latency.lua".text = ''
      alsa_monitor.rules = {
        {
          matches = {
            {
              -- Matches all sources.
              { "node.name", "matches", "alsa_input.*" },
            },
            {
              -- Matches all sinks.
              { "node.name", "matches", "alsa_output.*" },
            },
          },
          apply_properties = {
            ["audio.rate"] = "48000",
            ["api.alsa.headroom"] = 128,             -- Default: 0
            ["api.alsa.period-num"] = 2,             -- Default: 2
            ["api.alsa.period-size"] = 512,          -- Default: 1024
            ["api.alsa.disable-batch"] = false,      -- generally, USB soundcards use the batch mode
            ["resample.quality"] = 4,
            ["resample.disable"] = false,
            ["session.suspend-timeout-seconds"] = 0,
          },
        },
      }
    '';
  };
  hardware = {
    mwProCapture.enable = true;
    nvidia = {
      package = lib.mkForce config.boot.kernelPackages.nvidiaPackages.production;
      prime = {
        amdgpuBusId = "PCI:33:0:0";
        nvidiaBusId = "PCI:30:0:0";
        # Make the Radeon RX6700 XT default; the NVIDIA T1000 is for CUDA/NVENC
        reverseSync.enable = true;
      };
      nvidiaSettings = false;
    };
  };

  # Adjust MTU for Virgin Fibre
  # - https://search.nixos.org/options?channel=23.11&show=networking.networkmanager.connectionConfig&from=0&size=50&sort=relevance&type=packages&query=networkmanager
  networking.networkmanager.connectionConfig = {
    "ethernet.mtu" = 1462;
    "wifi.mtu" = 1462;
  };

  services = {
    cron = {
      enable = true;
      systemCronJobs = [
        "*/30 * * * * ${username} /home/${username}/Scripts/backup/sync-legoworlds.sh >> /home/${username}/Games/Steam_Backups/legoworlds.log"
        "42 * * * * ${username} /home/${username}/Scripts/backup/sync-hotshotracing.sh >> /home/${username}/Games/Steam_Backups/hotshotracing.log"
      ];
    };
    xserver.videoDrivers = [ "amdgpu" "nvidia" ];
  };
  nixpkgs.hostPlatform = lib.mkDefault "${platform}";
}
