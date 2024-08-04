_: {
  disko.devices = {
    disk = {
      nvme0 = {
        type = "disk";
        device = "/dev/disk/by-id/nvme-THNSN51T02DU7_NVMe_TOSHIBA_1024GB__66PS10N1T61V";
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              size = "1024M";
              type = "EF00";
              content = {
                format = "vfat";
                mountOptions = [
                  "defaults"
                  "umask=0077"
                ];
                mountpoint = "/boot";
                type = "filesystem";
              };
            };
            root = {
              size = "100%";
              content = {
                extraArgs = [
                  "-f"
                  "--compression=lz4"
                  "--discard"
                  "--encrypted"
                ];
                format = "bcachefs";
                mountOptions = [
                  "defaults"
                  "compression=lz4"
                  "discard"
                  "relatime"
                  "nodiratime"
                ];
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
