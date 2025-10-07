{ lib, ... }:
let
  # https://gist.github.com/braindevices/fde49c6a8f6b9aaf563fb977562aafec
  # Use ls -la /dev/disk/by-id to find the correct names.
  nvme0 = "/dev/disk/by-id/nvme-WD_BLACK_SN770M_1TB_234371800196";
  nvme1 = "/dev/disk/by-id/nvme-WD_BLACK_SN770_2TB_241958808606";
  defaultBtrfsOpts = [
    "compress=lzo"
    "discard=async"
    "noatime"
    "rw"
    "space_cache=v2"
    "ssd"
  ];
  # AES-XTS with 256-bit keys provides optimal security-performance balance.
  # Key size selection impacts performance. 256-bit keys (AES-128 equivalent)
  # provide 20% better performance than 512-bit keys (AES-256 equivalent)
  # with minimal security trade-offs.
  # LUKS2 with 4K sectors optimizes modern NVMe performance. This configuration
  # provides 8x more efficient AES-NI instruction usage and better alignment
  # with SSD internals.
  defaultExtraFormatArgs = [
    "--cipher=aes-xts-plain64"
    "--hash=sha256"
    "--iter-time=1000"
    "--key-size=256"
    "--pbkdf-memory=1048576"
    "--sector-size=4096"
  ];
in
{
  boot.initrd.luks.devices = {
    # Priority ensures cryptroot is unlocked before crypthome.
    cryptroot = {
      device = "/dev/disk/by-partlabel/disk-nvme0-cryptroot";
    };
  };

  disko.devices = {
    disk = {
      nvme0 = {
        type = "disk";
        device = nvme0;
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              size = "2048M";
              type = "EF00";
              content = {
                format = "vfat";
                mountOptions = [
                  "defaults"
                  "umask=0077"
                ];
                mountpoint = "/boot";
                type = "filesystem";
              };
            };
            cryptroot = {
              size = "100%";
              content = {
                type = "luks";
                name = "cryptroot";
                passwordFile = "/tmp/data.passwordFile";
                settings = {
                  allowDiscards = true;
                };
                extraFormatArgs = defaultExtraFormatArgs;
                content = {
                  type = "btrfs";
                  extraArgs = [
                    "--force"
                    "--label root"
                    "--sectorsize 4096"
                  ];
                  subvolumes = {
                    "@" = {
                      mountpoint = "/";
                      mountOptions = defaultBtrfsOpts;
                    };
                    "@nix" = {
                      mountpoint = "/nix";
                      mountOptions = defaultBtrfsOpts;
                    };
                  };
                };
              };
            };
          };
        };
      };
      nvme1 = {
        type = "disk";
        device = nvme1;
        content = {
          type = "gpt";
          partitions = {
            crypthome = {
              size = "100%";
              content = {
                type = "luks";
                name = "crypthome";
                passwordFile = "/tmp/data.passwordFile";
                settings = {
                  allowDiscards = true;
                };
                extraFormatArgs = defaultExtraFormatArgs;
                content = {
                  type = "btrfs";
                  extraArgs = [
                    "--force"
                    "--label home"
                    "--sectorsize 4096"
                  ];
                  subvolumes = {
                    "@home" = {
                      mountpoint = "/home";
                      mountOptions = defaultBtrfsOpts;
                    };
                  };
                };
              };
            };
          };
        };
      };
    };
  };
}
