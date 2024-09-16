# Motherboard:       Gigabye Z390 Designare
# CPU:               Intel i9 9900K
# GPU:               NVIDIA T400
# RAM:               64GB DDR4
# NVME0:             512GB Corsair Force MP600
# NVME1:             1TB Corsair Force MP600
# SATA2:             12TB Ultrastar He12
# SATA3:             12TB Ultrastar He12
# Slot 1 (PCIEX16):  Sedna PCIe Quad M.2 SATA III (6G) SSD Adapter (12TB)
# Slot 2 (PCIEX1_1): Sedna PCIe Dual M.2 SATA III (6G) SSD Adapter (4TB)
# Slot 3 (PCIEX8):   NVIDIA T400
# Slot 4 (PCIEX1_2): Sedna PCIe Dual M.2 SATA III (6G) SSD Adapter (4TB)
# Slot 5 (PCIEX4):   Sedna PCIe Quad M.2 SATA III (6G) SSD Adapter (12TB)

{
  inputs,
  pkgs,
  username,
  ...
}:
{
  imports = [
    inputs.nixos-hardware.nixosModules.common-cpu-intel
    inputs.nixos-hardware.nixosModules.common-gpu-nvidia
    inputs.nixos-hardware.nixosModules.common-pc
    inputs.nixos-hardware.nixosModules.common-pc-ssd
    ./disks.nix
    ./disks-home.nix
    ./disks-snapraid.nix
    ./disks-snapshot.nix
  ];

  boot = {
    initrd.availableKernelModules = [
      "ahci"
      "nvme"
      "uas"
      "usbhid"
      "sd_mod"
      "xhci_pci"
    ];
    kernelModules = [
      "kvm-intel"
      "nvidia"
    ];
    swraid = {
      enable = true;
      mdadmConf = "PROGRAM=true";
    };
  };

  environment.systemPackages = with pkgs; [
    mergerfs
    mergerfs-tools
  ];

  fileSystems."/srv/pool" = {
    fsType = "fuse.mergerfs";
    device = "/mnt/data_*";
    options = [
      "cache.files=partial"
      "category.create=mspmfs"
      "dropcacheonclose=true"
      "fsname=pool"
      "minfreespace=16G"
      "moveonenospc=true"
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
        nvidiaBusId = "PCI:2:0:0";
        # Make the Intel iGPU default. The NVIDIA T400 is for CUDA/NVENC
        reverseSync.enable = true;
      };
    };
  };

  services = {
    snapraid = {
      enable = true;
      exclude = [ "/.state_data/" ];
      extraConfig = ''
        autosave 256
      '';
      contentFiles = [
        "/home/${username}/.snapraid.content"
        "/mnt/data_01/.snapraid.content"
        "/mnt/data_06/.snapraid.content"
      ];
      dataDisks = {
        d1 = "/mnt/data_01/";
        d2 = "/mnt/data_02/";
        d3 = "/mnt/data_03/";
        d4 = "/mnt/data_04/";
        d5 = "/mnt/data_05/";
        d6 = "/mnt/data_06/";
        d7 = "/mnt/data_07/";
        d8 = "/mnt/data_08/";
      };
      parityFiles = [
        "/mnt/parity_01/snapraid.parity"
        "/mnt/parity_02/snapraid.parity"
      ];
      touchBeforeSync = true;
    };
    udev.extraRules = ''
      # Remove NVIDIA Audio devices, if present
      ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x040300", ATTR{power/control}="auto", ATTR{remove}="1"
    '';
  };

  #Seed the initial directories to coerce mergerfs mspmfs to "balance" the data
  # - Balance Films over data_01,06 (2x4TB)
  # - Balance TV over data_02,04,07 (3x2TB)
  # - Balance everything else over data_03,05,08 (3x2TB)
  systemd.tmpfiles.rules = [
    "d /mnt/data_01/Films           0755 ${username} users"
    "d /mnt/data_01/Films_Education 0755 ${username} users"
    "d /mnt/data_01/Films_Kids      0755 ${username} users"
    "d /mnt/data_01/Films_Short     0755 ${username} users"
    "d /mnt/data_01/Films_Archived  0755 ${username} users"
    "d /mnt/data_06/Films           0755 ${username} users"
    "d /mnt/data_06/Films_Education 0755 ${username} users"
    "d /mnt/data_06/Films_Kids      0755 ${username} users"
    "d /mnt/data_06/Films_Short     0755 ${username} users"
    "d /mnt/data_06/Films_Archived  0755 ${username} users"

    "d /mnt/data_02/TV              0755 ${username} users"
    "d /mnt/data_02/TV_Kids         0755 ${username} users"
    "d /mnt/data_04/TV              0755 ${username} users"
    "d /mnt/data_04/TV_Kids         0755 ${username} users"
    "d /mnt/data_07/TV              0755 ${username} users"
    "d /mnt/data_07/TV_Kids         0755 ${username} users"

    "d /mnt/data_03/Archive         0755 ${username} users"
    "d /mnt/data_03/Films_Home      0755 ${username} users"
    "d /mnt/data_03/Internet        0755 ${username} users"
    "d /mnt/data_03/Internet_Kids   0755 ${username} users"
    "d /mnt/data_03/Projects        0755 ${username} users"
    "d /mnt/data_03/Retro           0755 ${username} users"
    "d /mnt/data_05/Archive         0755 ${username} users"
    "d /mnt/data_05/Films_Home      0755 ${username} users"
    "d /mnt/data_05/Internet        0755 ${username} users"
    "d /mnt/data_05/Internet_Kids   0755 ${username} users"
    "d /mnt/data_05/Projects        0755 ${username} users"
    "d /mnt/data_05/Retro           0755 ${username} users"
    "d /mnt/data_08/Archive         0755 ${username} users"
    "d /mnt/data_08/Films_Home      0755 ${username} users"
    "d /mnt/data_08/Internet        0755 ${username} users"
    "d /mnt/data_08/Internet_Kids   0755 ${username} users"
    "d /mnt/data_08/Projects        0755 ${username} users"
    "d /mnt/data_08/Retro           0755 ${username} users"

    "d /mnt/parity_01               0755 ${username} users"
    "d /mnt/parity_02               0755 ${username} users"
    "d /srv/pool                    0755 ${username} users"
  ];
}
