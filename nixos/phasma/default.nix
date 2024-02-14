{ config, inputs, lib, pkgs, platform, ... }:
{
  imports = [
    inputs.nixos-hardware.nixosModules.common-cpu-amd
    inputs.nixos-hardware.nixosModules.common-cpu-amd-pstate
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
    ../_mixins/services/bluetooth.nix
    ../_mixins/services/clamav.nix
    ../_mixins/services/filesync.nix
    ../_mixins/services/openrazer.nix
    ../_mixins/services/pipewire.nix
    ../_mixins/services/tailscale.nix
    ../_mixins/services/zerotier-gaming.nix
    ../_mixins/virt
  ];

  # disko does manage mounting / and /boot, but I want to mount by-partlabel
  #fileSystems = {
  #  "/" = lib.mkForce {
  #    device = "/dev/disk/by-label/root";
  #    fsType = "xfs";
  #    options = [ "defaults" "relatime" "nodiratime" ];
  #  };
  #  "/boot" = lib.mkForce {
  #    device = "/dev/disk/by-label/ESP";
  #    fsType = "vfat";
  #  };
  #};

  boot = {
    blacklistedKernelModules = lib.mkDefault [ "nouveau" ];
    initrd.availableKernelModules = [ "nvme" "ahci" "xhci_pci" "usbhid" "uas" "sd_mod" ];
    kernelModules = [ "amdgpu" "kvm-amd" "nvidia" ];
    kernelPackages = pkgs.linuxPackages_latest;
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
    "pipewire/pipewire.conf.d/92-low-latency.conf".text = ''
      context.properties = {
        default.clock.rate = 48000
        default.clock.quantum = 64
        default.clock.min-quantum = 64
        default.clock.max-quantum = 64
      }
    '';
    # Change this to use: services.pipewire.extraConfig.pipewire-pulse
    "pipewire/pipewire-pulse.d/92-low-latency.conf".source = json.generate "92-low-latency.conf" {
      context.modules = [
        {
          name = "libpipewire-module-protocol-pulse";
          args = {
            pulse.min.req = "64/48000";
            pulse.default.req = "64/48000";
            pulse.max.req = "64/48000";
            pulse.min.quantum = "64/48000";
            pulse.max.quantum = "64/48000";
          };
        }
      ];
      stream.properties = {
        node.latency = "64/48000";
        resample.quality = 1;
      };
    };
    # https://stackoverflow.com/questions/24040672/the-meaning-of-period-in-alsa
    # https://gitlab.freedesktop.org/pipewire/pipewire/-/issues/3241
    "wireplumber/main.lua.d/92-low-latency.lua".text = ''
      alsa_monitor.rules = {
        {
          matches = {{{ "node.name", "matches", "alsa_output.*" }}};
          apply_properties = {
            ["audio.format"] = "S32LE",
            ["audio.rate"] = "96000", -- for USB soundcards it should be twice your desired rate
            ["api.alsa.period-size"] = 2, -- defaults to 1024, tweak by trial-and-error
            ["api.alsa.disable-batch"] = false, -- generally, USB soundcards use the batch mode
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
        amdgpuBusId = "PCI:34:0:0";
        nvidiaBusId = "PCI:31:0:0";
        # Make the Radeon RX6700 XT default; the NVIDIA T600 is for CUDA/NVENC
        reverseSync.enable = true;
      };
      nvidiaSettings = false;
    };
  };

  services = {
    hardware.openrgb = {
      enable = true;
      motherboard = "amd";
      package = pkgs.openrgb-with-all-plugins;
    };
    xserver.videoDrivers = [ "amdgpu" "nvidia" ];
  };
  nixpkgs.hostPlatform = lib.mkDefault "${platform}";
}
