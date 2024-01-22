# nvme0n1 2TB:   NixOS

{ disks ? [ "/dev/disk/by-id/nvme-Corsair_MP600_CORE_212479080001303710B4" ], ... }:{
  disko.devices = {
    disk = {
      nixos1 = {
        type = "disk";
        device = builtins.elemAt disks 0;
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
                mountOptions = [ "defaults" "umask=0077" ];
              };
            }
            {
              name = "nixos";
              start = "550MiB";
              end = "100%";
              content = {
                type = "filesystem";
                # Overwirte the existing filesystem
                extraArgs = [ "-f" "--compression=lz4:1" "background_compression=lz4:0" "--fs_label=nixos" "--label=nixos" "--discard" ];
                format = "bcachefs";
                mountpoint = "/";
                mountOptions = [ "defaults" "relatime" "compression=lz4:1" "background_compression=lz4:0" "discard" ];
              };
            }
          ];
        };
      };
    };
  };
}
