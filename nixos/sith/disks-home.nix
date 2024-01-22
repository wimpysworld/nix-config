# nvme1n1 4TB:   /home

{ disks ? [ "/dev/disk/by-id/nvme-Corsair_MP600_CORE_21177909000130384189" ], ... }:{
  disko.devices = {
    disk = {
      home1 = {
        type = "disk";
        device = builtins.elemAt disks 0;
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
                extraArgs = [ "-f" "--fs_label=home" "--label=home" "--discard" ];
                format = "bcachefs";
                mountpoint = "/home";
                mountOptions = [ "defaults" "relatime" "discard" ];
              };
            }
          ];
        };
      };
    };
  };
}
