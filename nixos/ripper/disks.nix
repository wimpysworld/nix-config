# nvme0n1 500GB: Windows 11
# nvme1n1 1TB:   NixOS
# nvme2n1 4TB:   Snapshot RAID-0
# nvme3n1 4TB:   Snapshot RAID-0
# nvme4n1 2TB:   Home RAID-5
# nvme5n1 2TB:   Home RAID-5
# nvme6n1 2TB:   Home RAID-5
# nvme7n1 2TB:   Home RAID-5
# sda     12TB:  Archive
# sdb     12TB:  Archive
{ disks ? [ "/dev/nvme1n1" "/dev/nvme2n1" "/dev/nvme3n1" "/dev/nvme4n1" "/dev/nvme5n1" "/dev/nvme6n1" "/dev/nvme7n1" ], ... }:
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
            name = "ESP";
            start = "0%";
            end = "550MiB";
            bootable = true;
            flags = [ "esp" ];
            fs-type = "fat32";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
            };
          }
            {
              name = "root";
              start = "550MiB";
              end = "100%";
              content = {
                type = "filesystem";
                # Overwirte the existing filesystem
                extraArgs = [ "-f" ];
                format = "xfs";
                mountpoint = "/";
                mountOptions = defaultXfsOpts;
              };
            }];
        };
      };
      # Snapshot RAID-0
      nvme2 = {
        type = "disk";
        device = builtins.elemAt disks 1;
        content = {
          type = "table";
          format = "gpt";
          partitions = [{
            name = "snapshot-nvme2";
            start = "0%";
            end = "100%";
            content = {
              type = "mdraid";
              name = "snapshot";
            };
          }];
        };
      };
      nvme3 = {
        type = "disk";
        device = builtins.elemAt disks 2;
        content = {
          type = "table";
          format = "gpt";
          partitions = [{
            name = "snapshot-nvme3";
            start = "0%";
            end = "100%";
            content = {
              type = "mdraid";
              name = "snapshot";
            };
          }];
        };
      };
      # Home RAID-5
      nvme4 = {
        type = "disk";
        device = builtins.elemAt disks 3;
        content = {
          type = "table";
          format = "gpt";
          partitions = [{
            name = "home-nvme4";
            start = "0%";
            end = "100%";
            content = {
              type = "mdraid";
              name = "home";
            };
          }];
        };
      };
      nvme5 = {
        type = "disk";
        device = builtins.elemAt disks 4;
        content = {
          type = "table";
          format = "gpt";
          partitions = [{
            name = "home-nvme5";
            start = "0%";
            end = "100%";
            content = {
              type = "mdraid";
              name = "home";
            };
          }];
        };
      };
      nvme6 = {
        type = "disk";
        device = builtins.elemAt disks 5;
        content = {
          type = "table";
          format = "gpt";
          partitions = [{
            name = "home-nvme6";
            start = "0%";
            end = "100%";
            content = {
              type = "mdraid";
              name = "home";
            };
          }];
        };
      };
      nvme7 = {
        type = "disk";
        device = builtins.elemAt disks 6;
        content = {
          type = "table";
          format = "gpt";
          partitions = [{
            name = "home-nvme7";
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
      snapshot = {
        type = "mdadm";
        level = 0;
        content = {
          type = "table";
          format = "gpt";
          partitions = [{
            name = "primary";
            start = "0%";
            end = "100%";
            content = {
              type = "filesystem";
              # Overwirte the existing filesystem
              extraArgs = [ "-f" ];
              format = "xfs";
              mountpoint = "/mnt/snapshot";
              mountOptions = defaultXfsOpts;
            };
          }];
        };
      };
      home = {
        type = "mdadm";
        level = 5;
        content = {
          type = "table";
          format = "gpt";
          partitions = [{
            name = "primary";
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
          }];
        };
      };
    };
  };
}
