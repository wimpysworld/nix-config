# nvme0n1 2TB:   NixOS
# nvme1n1 4TB:   Home RAID-0
# nvme2n1 4TB:   Home RAID-0
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
            snapshot-sda = {
              start = "0%";
              end = "100%";
              content = {
                type = "mdraid";
                name = "snapshot";
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
            snapshot-sdb = {
              start = "0%";
              end = "100%";
              content = {
                type = "mdraid";
                name = "snapshot";
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
            snapshot-sdc = {
              start = "0%";
              end = "100%";
              content = {
                type = "mdraid";
                name = "snapshot";
              };
            };
          };
        };
      };
    };
    mdadm = {
      snapshot = {
        type = "mdadm";
        level = 0;
        content = {
          type = "gpt";
          partitions = {
            snapshot = {
              start = "0%";
              end = "100%";
              content = {
                type = "filesystem";
                # Overwirte the existing filesystem
                extraArgs = [ "-f" ];
                format = "xfs";
                mountpoint = "/mnt/snapshot";
                mountOptions = [ "defaults" ];
              };
            };
          };
        };
      };
    };
  };
}
