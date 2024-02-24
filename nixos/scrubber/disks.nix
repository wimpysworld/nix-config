{ disks ? [ "/dev/vda" ], ... }:
let
  defaultBcachefsOpts = [ "defaults" "relatime" "nodiratime" ];
in
{
  disko.devices = {
    disk = {
      vda = {
        type = "disk";
        device = builtins.elemAt disks 0;
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              start = "0%";
              end = "1024MiB";
              type = "EF00";
              content = {
                format = "vfat";
                mountOptions = [ "defaults" "umask=0077" ];
                mountpoint = "/boot";
                type = "filesystem";
              };
            };
            root = {
              size = "100%";
              content = {
                extraArgs = [ "-f" ];
                format = "bcachefs";
                mountOptions = defaultBcachefsOpts;
                mountpoint = "/";
                type = "filesystem";
              };
            };
          };
        };
      };
    };
  };
}
