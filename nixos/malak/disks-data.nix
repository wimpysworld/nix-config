#/dev/disk/by-id/ata-HGST_HUH721008ALE600_4DG8TRRZ -> ../../sda
#/dev/disk/by-id/ata-HGST_HUH721008ALE600_4DG88HDZ -> ../../sdb
_: {
  disko.devices = {
    disk = {
      HGST_4DG8TRRZ = {
        type = "disk";
        device = "/dev/disk/by-id/ata-HGST_HUH721008ALE600_4DG8TRRZ";
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
      HGST_4DG88HDZ = {
        type = "disk";
        device = "/dev/disk/by-id/ata-HGST_HUH721008ALE600_4DG88HDZ";
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
                mountpoint = "/mnt/data";
                mountOptions = [ "defaults" ];
              };
            };
          };
        };
      };
    };
  };
}
