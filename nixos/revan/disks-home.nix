# nvme0n1 512GB: NixOS
# nvme1n1 1TB:   Home
_: {
  disko.devices = {
    disk = {
      nvme1 = {
        type = "disk";
        device = "/dev/disk/by-id/nvme-Force_MP600_20378229000128554100";
        content = {
          type = "gpt";
          partitions = {
            home = {
              start = "0%";
              end = "100%";
              content = {
                type = "filesystem";
                # Overwirte the existing filesystem
                extraArgs = [ "-f" ];
                format = "xfs";
                mountpoint = "/home";
                mountOptions = [ "defaults" ];
              };
            };
          };
        };
      };
    };
  };
}
