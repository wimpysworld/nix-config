{ disks ? [ "/dev/vda" ], ... }: {
  disko.devices = {
    disk = {
      vda = {
        type = "disk";
        device = builtins.elemAt disks 0;
        content = {
          type = "table";
          format = "gpt";
          partitions = [
            {
              name = "grub";
              start = "0%";
              end = "1M";
              flags = [ "bios_grub" ];
            }
            {
              bootable = true;
              name = "ESP";
              start = "1M";
              end = "512M";
              flags = [ "esp" ];
              fs-type = "fat32";
              content = {
                format = "vfat";
                mountOptions = [ "defaults" "umask=0077" ];
                mountpoint = "/boot";
                type = "filesystem";
              };
            }
            {
              name = "swap";
              start = "512M";
              end = "1536M";
              content = {
                extraArgs = [ "-f" ];
                randomEncryption = false;
                resumeDevice = false;
                type = "swap";
              };
            }
            {
              name = "root";
              start = "1536M";
              end = "100%";
              content = {
                extraArgs = [ "-f" "--fs_label=root" ];
                format = "bcachefs";
                mountOptions = [ "defaults" "relatime" "nodiratime" ];
                mountpoint = "/";
                type = "filesystem";
              };
            }
          ];
        };
      };
    };
  };
}
