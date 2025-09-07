#Node                  Generic               SN                   Model                                    Namespace  Usage                      Format           FW Rev
#--------------------- --------------------- -------------------- ---------------------------------------- ---------- -------------------------- ---------------- --------
#/dev/nvme0n1          /dev/ng0n1            2336E873DCBF         CT4000P3PSSD8                            0x1          4.00  TB /   4.00  TB    512   B +  0 B   P9CR40A
#/dev/nvme1n1          /dev/ng1n1            212479080001303710B4 Corsair MP600 CORE                       0x1          2.00  TB /   2.00  TB    512   B +  0 B   EGFM52.3
#/dev/nvme2n1          /dev/ng2n1            21177909000130384189 Corsair MP600 CORE                       0x1          4.00  TB /   4.00  TB    512   B +  0 B   EGFM52.3
_: {
  disko.devices = {
    disk = {
      nvme0 = {
        type = "disk";
        device = "/dev/disk/by-id/nvme-CT4000P3PSSD8_2336E873DCBF";
        content = {
          type = "gpt";
          partitions = {
            home_p1 = {
              size = "100%";
              content = {
                type = "luks";
                name = "home_p1";
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
      nvme2 = {
        type = "disk";
        device = "/dev/disk/by-id/nvme-Corsair_MP600_CORE_21177909000130384189";
        content = {
          type = "gpt";
          partitions = {
            home_p2 = {
              size = "100%";
              content = {
                type = "luks";
                name = "home_p2";
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
                  # --metadata raid1    Creates 2 copies of metadata (one on each drive) for max integrity.
                  extraArgs = [
                    "--force"
                    "--data raid0"
                    "--label home"
                    "--metadata raid1"
                    "--sectorsize 4096"
                    "/dev/mapper/home_p1" # Use decrypted mapped device, 'name' as defined in nvme1
                  ];
                  subvolumes = {
                    "/home" = {
                      mountpoint = "/home";
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
