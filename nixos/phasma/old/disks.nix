# nvme0n1 2TB:   NixOS
# nvme1n1 4TB:   Home RAID-0
# nvme2n1 4TB:   Home RAID-0
# sda     4TB:   Backup RAID-0
# sdb     4TB:   Backup RAID-0
# sdc     4TB:   Backup RAID-0
{
  lib,
  username,
  ...
}:
{
  boot = {
    swraid = {
      enable = true;
      mdadmConf = "MAILADDR=${username}@wimpys.world";
    };
  };
  # TODO: Remove this if/when machine is reinstalled.
  # This is a workaround for the legacy -> gpt tables disko format.
  fileSystems = {
    "/".device = lib.mkForce "/dev/disk/by-partlabel/root";
    "/boot".device = lib.mkForce "/dev/disk/by-partlabel/ESP";
  };
  disko.devices = {
    disk = {
      nvme0 = {
        type = "disk";
        device = "/dev/disk/by-id/nvme-Corsair_MP600_CORE_212479080001303710B4";
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              start = "0%";
              end = "1024MiB";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountOptions = [
                  "defaults"
                  "umask=0077"
                ];
                mountpoint = "/boot";
              };
            };
            root = {
              start = "1024MiB";
              end = "100%";
              content = {
                type = "filesystem";
                # Overwirte the existing filesystem
                extraArgs = [ "-f" ];
                format = "xfs";
                mountpoint = "/";
                mountOptions = [ "defaults" ];
              };
            };
          };
        };
      };
    };
  };
}
