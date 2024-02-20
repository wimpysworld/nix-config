# nvme0n1 2TB:     NixOS
# nvme1n1 512GB:   Windows 11 Pro
{ disks ? [ "/dev/nvme0n1" ], ... }:
let
  defaultXfsOpts = [ "defaults" "relatime" "nodiratime" ];
in
{
  disko.devices = {
    disk = {
      nvme0 = {
        type = "disk";
        device = builtins.elemAt disks 0;
        content = {
          type = "table";
          format = "gpt";
          partitions = [
            {
              name = "ESP";
              start = "0%";
              end = "1024MiB";
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
              start = "1024MiB";
              end = "100%";
              content = {
                type = "filesystem";
                # Overwirte the existing filesystem
                extraArgs = [ "-f" ];
                format = "xfs";
                mountpoint = "/";
                mountOptions = defaultXfsOpts;
              };
            }
          ];
        };
      };
    };
  };
}
