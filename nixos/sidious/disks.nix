# nvme0n1 2TB:     NixOS              nvme-Samsung_SSD_970_EVO_2TB_S464NB0K800345W
# nvme1n1 512GB:   Windows 11 Pro     nvme-Samsung_SSD_970_EVO_500GB_S466NB0K703260N
_: {
  disko.devices = {
    disk = {
      nvme0 = {
        type = "disk";
        device = "/dev/disk/by-id/nvme-Samsung_SSD_970_EVO_2TB_S464NB0K800345W";
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
