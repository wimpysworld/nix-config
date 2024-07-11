_: {
  disko.devices = {
    disk = {
      nvme0 = {
        type = "disk";
        device = "/dev/nvme0n1";
        content = {
          type = "table";
          format = "gpt";
          partitions = [
            {
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
                mountOptions = [
                  "defaults"
                  "relatime"
                  "nodiratime"
                ];
              };
            }
          ];
        };
      };
      nvme1 = {
        type = "disk";
        device = "/dev/nvme1n1";
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
