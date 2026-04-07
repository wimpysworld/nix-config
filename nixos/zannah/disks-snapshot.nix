# sda     4TB:   Backup RAID-0
# sdb     4TB:   Backup RAID-0
_: {
  disko.devices = {
    disk = {
      sda = {
        type = "disk";
        device = "/dev/disk/by-id/ata-TS4TMTS830S_H986540082";
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
        device = "/dev/disk/by-id/ata-TS4TMTS830S_H986540074";
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
