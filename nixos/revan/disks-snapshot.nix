#/dev/disk/by-id/ata-HGST_HUH721212ALE600_5PK0ANNB: 12TB Backup (RAID-0)
#/dev/disk/by-id/ata-HGST_HUH721212ALE600_5PK2T14B: 12TB Backup (RAID-0)
_: {
  disko.devices = {
    disk = {
      HGST_5PK0ANNB = {
        type = "disk";
        device = "/dev/disk/by-id/ata-HGST_HUH721212ALE600_5PK0ANNB";
        content = {
          type = "gpt";
          partitions = {
            snapshot = {
              size = "100%";
              content = {
                type = "mdraid";
                name = "snapshot";
              };
            };
          };
        };
      };
      HGST_5PK2T14B = {
        type = "disk";
        device = "/dev/disk/by-id/ata-HGST_HUH721212ALE600_5PK2T14B";
        content = {
          type = "gpt";
          partitions = {
            snapshot = {
              size = "100%";
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
              size = "100%";
              content = {
                type = "filesystem";
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
