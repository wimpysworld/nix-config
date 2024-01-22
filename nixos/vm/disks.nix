{ disks ? [ "/dev/vda" ], ... }: {
  disko.devices = {
    disk = {
      nixos = {
        type = "disk";
        device = builtins.elemAt disks 0;
        content = {
          type = "table";
          format = "gpt";
          partitions = [
            {
              name = "boot";
              start = "0%";
              end = "1M";
              flags = [ "bios_grub" ];
            }
            {
              name = "ESP";
              start = "1M";
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
              name = "root";
              start = "550MiB";
              end = "100%";
              content = {
                type = "filesystem";
                # Overwirte the existing filesystem
                extraArgs = [ "-f" "--compression=lz4:0" "--fs_label=nixos" ];
                format = "bcachefs";
                mountpoint = "/";
                mountOptions = [ "defaults" "relatime" "compression=lz4:0" ];
              };
            }
          ];
        };
      };
    };
  };
}
