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
            sda = {
              size = "100%";
              content = {
                type = "mdraid";
                name = "data";
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
            sdb = {
              size = "100%";
              content = {
                type = "mdraid";
                name = "data";
              };
            };
          };
        };
      };
    };
    mdadm = {
      data = {
        type = "mdadm";
        level = 1;
        content = {
          type = "gpt";
          partitions = {
            primary = {
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
