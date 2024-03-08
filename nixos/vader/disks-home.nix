# nvme0n1 2TB:   NixOS
# nvme1n1 4TB:   Home RAID-0
# nvme2n1 4TB:   Home RAID-0
# sda     4TB:   Backup RAID-0
# sdb     4TB:   Backup RAID-0
# sdc     4TB:   Backup RAID-0
_: {
  disko.devices = {
    disk = {
      nvme1 = {
        type = "disk";
        device = "/dev/disk/by-id/nvme-Force_MP510_20258273000129622040";
        content = {
          type = "gpt";
          partitions = {
            home-nvme1 = {
              start = "0%";
              end = "100%";
              content = {
                type = "mdraid";
                name = "home";
              };
            };
          };
        };
      };
      nvme2 = {
        type = "disk";
        device = "/dev/disk/by-id/nvme-Force_MP510_2037827300012962401B";
        content = {
          type = "gpt";
          partitions = {
            home-nvme2 = {
              start = "0%";
              end = "100%";
              content = {
                type = "mdraid";
                name = "home";
              };
            };
          };
        };
      };
    };
    mdadm = {
      home = {
        type = "mdadm";
        level = 0;
        content = {
          type = "gpt";
          partitions = {
            home = {
              start = "0%";
              end = "100%";
              content = {
                type = "filesystem";
                # Overwirte the existing filesystem
                extraArgs = [ "-f" ];
                format = "xfs";
                mountpoint = "/home";
                mountOptions = [ "defaults" ];
              };
            };
          };
        };
      };
    };
  };
}
