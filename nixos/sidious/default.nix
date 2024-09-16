# Lenovo ThinkPad P1 Gen 1

{ inputs, lib, ... }:
{
  imports = [
    inputs.nixos-hardware.nixosModules.lenovo-thinkpad-p1
    inputs.nixos-hardware.nixosModules.common-gpu-nvidia
    inputs.nixos-hardware.nixosModules.common-hidpi
    ./disks.nix
  ];

  boot = {
    initrd.availableKernelModules = [
      "xhci_pci"
      "nvme"
      "uas"
      "usb_storage"
      "sd_mod"
    ];
    initrd.systemd.enable = true;
    kernelModules = [
      "kvm-intel"
      "nvidia"
    ];
  };

  hardware = {
    nvidia = {
      # upgrade-hint: NVIDIA driver FTBFS with Linux 6.10
      package = config.boot.kernelPackages.nvidiaPackages.mkDriver {
        version = "555.58.02";
        sha256_64bit = "sha256-xctt4TPRlOJ6r5S54h5W6PT6/3Zy2R4ASNFPu8TSHKM=";
        sha256_aarch64 = "sha256-wb20isMrRg8PeQBU96lWJzBMkjfySAUaqt4EgZnhyF8=";
        openSha256 = "sha256-8hyRiGB+m2hL3c9MDA/Pon+Xl6E788MZ50WrrAGUVuY=";
        settingsSha256 = "sha256-ZpuVZybW6CFN/gz9rx+UJvQ715FZnAOYfHn5jt5Z2C8=";
        persistencedSha256 = "sha256-a1D7ZZmcKFWfPjjH1REqPM5j/YLWKnbkP9qfRyIyxAw=";
      };
      prime = {
        intelBusId = "PCI:0:2:0";
        nvidiaBusId = "PCI:1:0:0";
        offload = {
          enable = true;
          enableOffloadCmd = true;
        };
        # Make the Intel iGPU default. The NVIDIA Quadro is for CUDA/NVENC
        reverseSync.enable = true;
      };
    };
  };

  # libfprint-2-tod1-vfs0090 in nixpkgs is from https://gitlab.freedesktop.org/3v1n0/libfprint-tod-vfs0090
  # - Supports Validity Sensor 138a:0090 and 138a:0097
  # The ThinkPad P1 Gen 1 has a Synaptics Sensor 06cb:009a; the project below supports it
  # - https://gitlab.com/bingch/libfprint-tod-vfs0090
  # - https://github.com/uunicorn/python-validity
  # - https://github.com/tester1969/pam-validity
  # TODO: Package the above project as libfprint-2-tod1-vfs009a
  services = {
    fprintd = {
      enable = lib.mkDefault false;
      #tod.enable = true;
      #tod.driver = pkgs.libfprint-2-tod1-vfs0090;
    };
  };
  services.xserver.videoDrivers = [
    "i915"
    "nvidia"
  ];
}
