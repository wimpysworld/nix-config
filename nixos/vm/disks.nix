{ disks ? [ "/dev/vda" ], ... }:
let
  defaultXfsOpts = [ "defaults" "relatime" "nodiratime" ];
in
{
  disko.devices = {
    disk = {
      vda = {
        type = "disk";
        device = builtins.elemAt disks 0;
        content = {
          type = "table";
          format = "gpt";
          partitions = [{
            name = "boot";
            start = "0%";
            end = "1M";
            flags = [ "bios_grub" ];
          }
            {
              name = "ESP";
              start = "1M";
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
    };
  };
}
