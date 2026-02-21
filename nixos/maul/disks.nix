#nvme list
#Node                  Generic               SN                   Model                                    Namespace  Usage                      Format           FW Rev
#--------------------- --------------------- -------------------- ---------------------------------------- ---------- -------------------------- ---------------- --------
#/dev/nvme0n1          /dev/ng0n1            SN202808914446       GIGABYTE GP-ASM2NE6200TTTD               0x1          2.00  TB /   2.00  TB    512   B +  0 B   EGFM13.2
#/dev/nvme1n1          /dev/ng1n1            SN202808914317       GIGABYTE GP-ASM2NE6200TTTD               0x1          2.00  TB /   2.00  TB    512   B +  0 B   EGFM13.2
#/dev/nvme2n1          /dev/ng2n1            SN202808914316       GIGABYTE GP-ASM2NE6200TTTD               0x1          2.00  TB /   2.00  TB    512   B +  0 B   EGFM13.2
#/dev/nvme3n1          /dev/ng3n1            SN202808914315       GIGABYTE GP-ASM2NE6200TTTD               0x1          2.00  TB /   2.00  TB    512   B +  0 B   EGFM13.2

# Key Enrollment and Management Procedure
# While the NixOS configuration is declarative, the act of enrolling cryptographic keys
# into the LUKS header is an imperative, stateful operation that must be performed manually on the provisioned system.
# - Create a LUKS Header Backup: This is the most critical first step.
#   Before making any changes, create a backup of the LUKS header for each encrypted device.
#   This backup is a file that contains all key slots and metadata, and it is the ultimate recovery tool if the header on the disk becomes corrupted.

#   sudo cryptsetup luksHeaderBackup /dev/disk/by-id/nvme-GIGABYTE_GP-ASM2NE6200TTTD_SN202808914446-part2 --header-backup-file ~/Vaults/Secrets/LUKS/maul-nvme0-header-backup.img
#   sudo cryptsetup luksHeaderBackup /dev/disk/by-id/nvme-GIGABYTE_GP-ASM2NE6200TTTD_SN202808914317-part1 --header-backup-file ~/Vaults/Secrets/LUKS/maul-nvme1-header-backup.img
#   sudo cryptsetup luksHeaderBackup /dev/disk/by-id/nvme-GIGABYTE_GP-ASM2NE6200TTTD_SN202808914316-part1 --header-backup-file ~/Vaults/Secrets/LUKS/maul-nvme2-header-backup.img
#   sudo cryptsetup luksHeaderBackup /dev/disk/by-id/nvme-GIGABYTE_GP-ASM2NE6200TTTD_SN202808914315-part1 --header-backup-file ~/Vaults/Secrets/LUKS/maul-nvme3-header-backup.img

# - Enroll the Primary Yubikey: With the primary Yubikey plugged in, run the enrollment command.
#   This will prompt for the Yubikey's PIN and require a touch confirmation. systemd-cryptenroll
#   will automatically find and use the first available LUKS key slot.

#   sudo systemd-cryptenroll /dev/disk/by-id/nvme-GIGABYTE_GP-ASM2NE6200TTTD_SN202808914446-part2 --fido2-device=auto
#   sudo systemd-cryptenroll /dev/disk/by-id/nvme-GIGABYTE_GP-ASM2NE6200TTTD_SN202808914317-part1 --fido2-device=auto
#   sudo systemd-cryptenroll /dev/disk/by-id/nvme-GIGABYTE_GP-ASM2NE6200TTTD_SN202808914316-part1 --fido2-device=auto
#   sudo systemd-cryptenroll /dev/disk/by-id/nvme-GIGABYTE_GP-ASM2NE6200TTTD_SN202808914315-part1 --fido2-device=auto
#   Set `fido2Enrolled = true;` in this configuration file below to indicate that FIDO2 keys are enrolled.
#   Build and deploy the NixOS configuration to the system, which will ensure that the FIDO2 device is recognized and used during boot.

# - Enroll the Backup Yubikey: For redundancy, a second, backup Yubikey should be enrolled.
#   Unplug the primary key, insert the backup key, and run the exact same command again for each of the four partitions.
#   systemd-cryptenroll is intelligent enough to detect that the first FIDO2 slot is in use and will enroll the new key in the next available slot.[22]

#   sudo systemd-cryptenroll /dev/disk/by-id/nvme-GIGABYTE_GP-ASM2NE6200TTTD_SN202808914446-part2 --fido2-device=auto
#   sudo systemd-cryptenroll /dev/disk/by-id/nvme-GIGABYTE_GP-ASM2NE6200TTTD_SN202808914317-part1 --fido2-device=auto
#   sudo systemd-cryptenroll /dev/disk/by-id/nvme-GIGABYTE_GP-ASM2NE6200TTTD_SN202808914316-part1 --fido2-device=auto
#   sudo systemd-cryptenroll /dev/disk/by-id/nvme-GIGABYTE_GP-ASM2NE6200TTTD_SN202808914315-part1 --fido2-device=auto

# - Create a Recovery Key: For a worst-case scenario where both Yubikeys are lost or destroyed,
#   a high-entropy recovery key (essentially a very long, randomly generated password) should be created.
#   This key should be printed or written down and stored in a physically secure location:

#   sudo systemd-cryptenroll /dev/disk/by-id/nvme-GIGABYTE_GP-ASM2NE6200TTTD_SN202808914446-part2 --recovery-key
#   sudo systemd-cryptenroll /dev/disk/by-id/nvme-GIGABYTE_GP-ASM2NE6200TTTD_SN202808914317-part1 --recovery-key
#   sudo systemd-cryptenroll /dev/disk/by-id/nvme-GIGABYTE_GP-ASM2NE6200TTTD_SN202808914316-part1 --recovery-key
#   sudo systemd-cryptenroll /dev/disk/by-id/nvme-GIGABYTE_GP-ASM2NE6200TTTD_SN202808914315-part1 --recovery-key

# - Enroll a Traditional Passphrase (Optional but Recommended):
#   As a final fallback, it is wise to have a memorable passphrase enrolled as well.

#   sudo systemd-cryptenroll /dev/disk/by-id/nvme-GIGABYTE_GP-ASM2NE6200TTTD_SN202808914446-part2 --password
#   sudo systemd-cryptenroll /dev/disk/by-id/nvme-GIGABYTE_GP-ASM2NE6200TTTD_SN202808914317-part1 --password
#   sudo systemd-cryptenroll /dev/disk/by-id/nvme-GIGABYTE_GP-ASM2NE6200TTTD_SN202808914316-part1 --password
#   sudo systemd-cryptenroll /dev/disk/by-id/nvme-GIGABYTE_GP-ASM2NE6200TTTD_SN202808914315-part1 --password

# - Verify Key Slots: After enrollment, use the luksDump command to inspect the LUKS header and verify that all the keys (FIDO2, recovery, passphrase) have been successfully added to their respective slots.

#   sudo cryptsetup luksDump /dev/disk/by-id/nvme-GIGABYTE_GP-ASM2NE6200TTTD_SN202808914446-part2
#   sudo cryptsetup luksDump /dev/disk/by-id/nvme-GIGABYTE_GP-ASM2NE6200TTTD_SN202808914317-part1
#   sudo cryptsetup luksDump /dev/disk/by-id/nvme-GIGABYTE_GP-ASM2NE6200TTTD_SN202808914316-part1
#   sudo cryptsetup luksDump /dev/disk/by-id/nvme-GIGABYTE_GP-ASM2NE6200TTTD_SN202808914315-part1

#ssg nix eval .#nixosConfigurations.maul.config.boot.initrd.luks.devices --json
_:
let
  # Use ls -la /dev/disk/by-id to find the correct names.
  nvme0 = "/dev/disk/by-id/nvme-GIGABYTE_GP-ASM2NE6200TTTD_SN202808914446";
  nvme1 = "/dev/disk/by-id/nvme-GIGABYTE_GP-ASM2NE6200TTTD_SN202808914317";
  nvme2 = "/dev/disk/by-id/nvme-GIGABYTE_GP-ASM2NE6200TTTD_SN202808914316";
  nvme3 = "/dev/disk/by-id/nvme-GIGABYTE_GP-ASM2NE6200TTTD_SN202808914315";
  defaultBtrfsOpts = [
    "compress=zstd:1"
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
  boot = {
    initrd = {
      luks = {
        # Pass options to systemd-cryptsetup in the initrd.
        # This tells it to look for a FIDO2 device and gives it a 30-second
        # timeout before falling back to other methods (like a password prompt,
        # if one were configured as a fallback).
        devices."crypt0" = {
          crypttabExtraOpts = [
            "fido2-device=auto"
            "token-timeout=30"
          ];
        };
        devices."crypt1" = {
          crypttabExtraOpts = [
            "fido2-device=auto"
            "token-timeout=30"
          ];
        };
        devices."crypt2" = {
          crypttabExtraOpts = [
            "fido2-device=auto"
            "token-timeout=30"
          ];
        };
        devices."crypt3" = {
          crypttabExtraOpts = [
            "fido2-device=auto"
            "token-timeout=30"
          ];
        };
        # This is counter-intuitive but REQUIRED.
        # The native systemd-cryptenroll support replaces this older module.
        fido2Support = false;
      };
      # Enable support for the Btrfs filesystem.
      supportedFilesystems = [ "btrfs" ];
      # Use the systemd-based initrd, which is required for modern
      # LUKS unlocking features like FIDO2.
      systemd.enable = true;
    };
  };

  services = {
    btrfs.autoScrub = {
      fileSystems = [ "/" ];
      enable = true;
      interval = "weekly";
    };
  };

  disko.devices = {
    disk = {
      # Devices will be mounted and formatted in alphabetical order, and btrfs can only mount raids
      # when all devices are present. So we define an "empty" luks device on the first disk,
      # and the actual btrfs raid on the second disk, and the name of these entries matters!
      "nvme0" = {
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
                mountOptions = [ "umask=0077" ];
                mountpoint = "/boot";
                type = "filesystem";
              };
            };
            crypt0 = {
              size = "100%";
              content = {
                type = "luks";
                name = "crypt0";
                passwordFile = "/tmp/data.passwordFile";
                settings = {
                  allowDiscards = true;
                  # This is why boot.initrd.luks.devices.crypt0.crypttabExtraOpts is set above.
                  #crypttabExtraOpts = defaultCrypttabExtraOpts;
                };
                extraFormatArgs = defaultExtraFormatArgs;
                postCreateHook = ''
                  sudo systemd-cryptenroll ${nvme0}-part2 --fido2-device=auto
                '';
              };
            };
          };
        };
      };
      "nvme1" = {
        type = "disk";
        device = nvme1;
        content = {
          type = "gpt";
          partitions = {
            crypt1 = {
              start = "2048M";
              size = "100%";
              content = {
                type = "luks";
                name = "crypt1";
                passwordFile = "/tmp/data.passwordFile";
                settings = {
                  allowDiscards = true;
                  # This is why boot.initrd.luks.devices.crypt1.crypttabExtraOpts is set above.
                  #crypttabExtraOpts = defaultCrypttabExtraOpts;
                };
                extraFormatArgs = defaultExtraFormatArgs;
                postCreateHook = ''
                  sudo systemd-cryptenroll ${nvme1}-part1 --fido2-device=auto
                '';
              };
            };
          };
        };
      };
      "nvme2" = {
        type = "disk";
        device = nvme2;
        content = {
          type = "gpt";
          partitions = {
            crypt2 = {
              start = "2048M";
              size = "100%";
              content = {
                type = "luks";
                name = "crypt2";
                passwordFile = "/tmp/data.passwordFile";
                settings = {
                  allowDiscards = true;
                  # This is why boot.initrd.luks.devices.crypt2.crypttabExtraOpts is set above.
                  #crypttabExtraOpts = defaultCrypttabExtraOpts;
                };
                extraFormatArgs = defaultExtraFormatArgs;
                postCreateHook = ''
                  sudo systemd-cryptenroll ${nvme2}-part1 --fido2-device=auto
                '';
              };
            };
          };
        };
      };
      "nvme3" = {
        type = "disk";
        device = nvme3;
        content = {
          type = "gpt";
          partitions = {
            crypt3 = {
              start = "2048M";
              size = "100%";
              content = {
                type = "luks";
                name = "crypt3";
                passwordFile = "/tmp/data.passwordFile";
                settings = {
                  allowDiscards = true;
                  # crypttabExtraOpts does not work. You will be unable to unlock the device at boot.
                  # This is why boot.initrd.luks.devices.crypt3.crypttabExtraOpts is set above.
                  #crypttabExtraOpts = defaultCrypttabExtraOpts;
                };
                extraFormatArgs = defaultExtraFormatArgs;
                postCreateHook = ''
                  sudo systemd-cryptenroll ${nvme3}-part1 --fido2-device=auto
                '';
                content = {
                  type = "btrfs";
                  # --data     raid0    Stripes data across all four drives for max performance/capacity.
                  # --metadata raid1c4  Creates 4 copies of metadata (one on each drive) for max integrity.
                  extraArgs = [
                    "--force"
                    "--data raid0"
                    "--label root"
                    "--metadata raid1c4"
                    "--sectorsize 4096"
                    "/dev/mapper/crypt0" # Use decrypted mapped device, 'name' as defined in nvme0
                    "/dev/mapper/crypt1" # Use decrypted mapped device, 'name' as defined in nvme1
                    "/dev/mapper/crypt2" # Use decrypted mapped device, 'name' as defined in nvme2
                  ];
                  subvolumes = {
                    "/root" = {
                      mountpoint = "/";
                      mountOptions = defaultBtrfsOpts;
                    };
                    "/nix" = {
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
    };
  };
}
