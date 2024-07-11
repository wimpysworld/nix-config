_: {
  disko.devices = {
    disk = {
      nvme0 = {
        type = "disk";
        device = "/dev/disk/by-id/nvme-WD_PC_SN740_SDDPTQE-2T00_22504Z446124";
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
            luks = {
              size = "100%";
              content = {
                type = "luks";
                name = "crypted";
                settings.allowDiscards = true;
                passwordFile = "/tmp/data.passwordFile";
                content = {
                  extraArgs = [ "-f" ];
                  format = "xfs";
                  mountOptions = [
                    "defaults"
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
  };
}
