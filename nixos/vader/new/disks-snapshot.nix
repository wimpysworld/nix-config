# sda     4TB:   Backup RAID-0
# sdb     4TB:   Backup RAID-0
# sdc     4TB:   Backup RAID-0
_: {
  disko.devices = {
    disk = {
      sda = {
        type = "disk";
        device = "/dev/disk/by-id/ata-TS4TMTS830S_H986540080";
        content = {
          type = "gpt";
          partitions = {
            snapshot_p1 = {
              size = "100%";
              content = {
                type = "luks";
                name = "snapshot_p1";
                settings = {
                  allowDiscards = true;
                  keyFile = "/vault/luks.key";
                };
                extraFormatArgs = [
                  "--cipher=aes-xts-plain64"
                  "--hash=sha256"
                  "--iter-time=1000"
                  "--key-size=256"
                  "--pbkdf-memory=262144"
                  "--sector-size=4096"
                ];
              };
            };
          };
        };
      };
      sdb = {
        type = "disk";
        device = "/dev/disk/by-id/ata-TS4TMTS830S_H986540076";
        content = {
          type = "gpt";
          partitions = {
            snapshot_p2 = {
              size = "100%";
              content = {
                type = "luks";
                name = "snapshot_p2";
                settings = {
                  allowDiscards = true;
                  keyFile = "/vault/luks.key";
                };
                extraFormatArgs = [
                  "--cipher=aes-xts-plain64"
                  "--hash=sha256"
                  "--iter-time=1000"
                  "--key-size=256"
                  "--pbkdf-memory=262144"
                  "--sector-size=4096"
                ];
              };
            };
          };
        };
      };
      sdc = {
        type = "disk";
        device = "/dev/disk/by-id/ata-Samsung_SSD_870_QVO_4TB_S5STNF0R108211L";
        content = {
          type = "gpt";
          partitions = {
            snapshot_p3 = {
              size = "100%";
              content = {
                type = "luks";
                name = "snapshot_p3";
                settings = {
                  allowDiscards = true;
                  keyFile = "/vault/luks.key";
                };
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
                  # --data     raid0    Stripes data across all four drives for max performance/capacity.
                  # --metadata raid1c3  Creates 3 copies of metadata (one on each drive) for max integrity.
                  extraArgs = [
                    "--force"
                    "--data raid0"
                    "--label snapshot"
                    "--metadata raid1c3"
                    "--sectorsize 4096"
                    "/dev/mapper/snapshot_p1" # Use decrypted mapped device, 'name' as defined in sda
                    "/dev/mapper/snapshot_p2" # Use decrypted mapped device, 'name' as defined in sdb
                  ];
                  subvolumes = {
                    "/snapshot" = {
                      mountpoint = "/mnt/snapshot";
                      mountOptions = [
                        "rw"
                        "compress=zstd:3"
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
