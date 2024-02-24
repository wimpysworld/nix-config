{ disks ? [ "/dev/disk/by-id/nvme-WD_PC_SN740_SDDPTQE-2T00_22504Z446124" ], ... }:
let
  defaultBcachefsOpts = [ "defaults" "compression=lz4" "discard" "relatime" "nodiratime" ];
in
{
  disko.devices = {
    disk = {
      nvme0 = {
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
                extraArgs = [ "-f" "--compression=lz4" "--discard" "--encrypted" ];
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
