#Node                  Generic               SN                   Model                                    Namespace  Usage                      Format           FW Rev
#--------------------- --------------------- -------------------- ---------------------------------------- ---------- -------------------------- ---------------- --------
#/dev/nvme0n1          /dev/ng0n1            2336E873DCBF         CT4000P3PSSD8                            0x1          4.00  TB /   4.00  TB    512   B +  0 B   P9CR40A
#/dev/nvme1n1          /dev/ng1n1            212479080001303710B4 Corsair MP600 CORE                       0x1          2.00  TB /   2.00  TB    512   B +  0 B   EGFM52.3
#/dev/nvme2n1          /dev/ng2n1            21177909000130384189 Corsair MP600 CORE                       0x1          4.00  TB /   4.00  TB    512   B +  0 B   EGFM52.3

# Key Enrollment and Management Procedure
# While the NixOS configuration is declarative, the act of enrolling cryptographic keys
# into the LUKS header is an imperative, stateful operation that must be performed manually on the provisioned system.

# - Set FIDO2 PIN

#    ykman fido access change-pin

# - Create a LUKS Header Backup: This is the most critical first step.
#   Before making any changes, create a backup of the LUKS header for each encrypted device.
#   This backup is a file that contains all key slots and metadata, and it is the ultimate recovery tool if the header on the disk becomes corrupted.

#   sudo cryptsetup luksHeaderBackup /dev/disk/by-id/nvme-Corsair_MP600_CORE_212479080001303710B4-part2 --header-backup-file ~/Vaults/Secrets/LUKS/phasma-nvme0-header-backup-vault.img
#   sudo cryptsetup luksHeaderBackup /dev/disk/by-id/nvme-Corsair_MP600_CORE_212479080001303710B4-part3 --header-backup-file ~/Vaults/Secrets/LUKS/phasma-nvme0-header-backup-root.img

# - Enroll the Primary Yubikey: With the primary Yubikey plugged in, run the enrollment command.
#   This will prompt for the Yubikey's PIN and require a touch confirmation. systemd-cryptenroll
#   will automatically find and use the first available LUKS key slot.

#   sudo systemd-cryptenroll /dev/disk/by-id/nvme-Corsair_MP600_CORE_212479080001303710B4-part2 --fido2-device=auto --fido2-with-client-pin=true
_: {
  disko.devices = {
    disk = {
      nvme1 = {
        type = "disk";
        device = "/dev/disk/by-id/nvme-Corsair_MP600_CORE_212479080001303710B4";
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              start = "0%";
              end = "2000M";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountOptions = [ "umask=0077" ];
                mountpoint = "/boot";
              };
            };
            vault = {
              start = "2000M";
              end = "2048M";
              content = {
                type = "luks";
                name = "vault";
                passwordFile = "/tmp/data.passwordFile";
                settings = {
                  allowDiscards = true;
                };
                # LUKS2 with 4K sectors optimizes modern NVMe performance. This configuration
                # provides 8x more efficient AES-NI instruction usage and better alignment
                # with SSD internals.
                extraFormatArgs = [
                  "--cipher=serpent-xts-plain64"
                  "--hash=sha512"
                  "--iter-time=3000"
                  "--key-size=256"
                  "--pbkdf-memory=4194304"
                  "--sector-size=4096"
                ];
                content = {
                  format = "ext2";
                  type = "filesystem";
                  extraArgs = [
                    "-F"
                    "-L vault"
                    "-m 0"
                    "-N 128"
                    "-b 4096"
                  ];
                  mountpoint = "/vault";
                  # Disable periodic checks
                  # tune2fs -c 0 -i 0 /dev/mapper/vault
                  # Add "ro" to prevent accidental writes once the system is running.
                  mountOptions = [
                    "noatime"
                    "errors=remount-ro"
                  ];
                };
              };
            };
            root = {
              size = "100%";
              content = {
                type = "luks";
                name = "root";
                settings = {
                  allowDiscards = true;
                  keyFile = "/vault/luks.key";
                };
                # LUKS2 with 4K sectors optimizes modern NVMe performance. This configuration
                # provides 8x more efficient AES-NI instruction usage and better alignment
                # with SSD internals.
                extraFormatArgs = [
                  "--cipher=aes-xts-plain64"
                  "--hash=sha256"
                  "--iter-time=1000"
                  "--key-size=256"
                  "--pbkdf-memory=262144"
                  "--sector-size=4096"
                ];
                content = {
                  type = "btrfs";
                  extraArgs = [
                    "--force"
                    "--label root"
                    "--sectorsize 4096"
                  ];
                  subvolumes = {
                    "/root" = {
                      mountpoint = "/";
                      mountOptions = [
                        "rw"
                        "compress=zstd:3"
                        "noatime"
                        "ssd"
                      ];
                    };
                    "/nix" = {
                      mountpoint = "/nix";
                      mountOptions = [
                        "rw"
                        "compress=zstd:1"
                        "noatime"
                        "ssd"
                      ];
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
