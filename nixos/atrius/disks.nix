_: {
  disko.devices = {
    disk = {
      nvme0 = {
        type = "disk";
        device = "/dev/disk/by-id/nvme-SKHynix_HFS512GD9TNG-L5B0B_FD02N557312702M30";
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
