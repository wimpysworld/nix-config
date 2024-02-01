# nvme0n1 2TB:   NixOS
# nvme1n1 4TB:   Home RAID-0
# nvme2n1 4TB:   Home RAID-0
# sda     4TB:   Backup RAID-0
# sdb     4TB:   Backup RAID-0   
# sdc     4TB:   Backup RAID-0
{ disks ? [ "/dev/nvme1n1" "/dev/nvme2n1" ], ... }:
let
  defaultXfsOpts = [ "defaults" "relatime" "nodiratime" ];
in
{
  disko.devices = {
    disk = {
      nvme1 = {
        type = "disk";
        device = builtins.elemAt disks 0;
        content = {
          type = "table";
          format = "gpt";
          partitions = [{
            name = "home-nvme1";
            start = "0%";
            end = "100%";
            content = {
              type = "mdraid";
              name = "home";
            };
          }];
        };
      };
      nvme2 = {
        type = "disk";
        device = builtins.elemAt disks 1;
        content = {
          type = "table";
          format = "gpt";
          partitions = [{
            name = "home-nvme2";
            start = "0%";
            end = "100%";
            content = {
              type = "mdraid";
              name = "home";
            };
          }];
        };
      };
    };
    mdadm = {
      home = {
        type = "mdadm";
        level = 0;
        content = {
          type = "table";
          format = "gpt";
          partitions = [
            {
              name = "home";
              start = "0%";
              end = "100%";
              content = {
                type = "filesystem";
                # Overwirte the existing filesystem
                extraArgs = [ "-f" ];
                format = "xfs";
                mountpoint = "/home";
                mountOptions = defaultXfsOpts;
              };
            }
          ];
        };
      };
    };
  };
}
