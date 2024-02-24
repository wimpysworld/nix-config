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
              size = "1024M";
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
