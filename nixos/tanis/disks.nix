{ lib, ... }:
let
  defaultBcachefsOpts = [ "defaults" "compression=lz4" "discard" "relatime" "nodiratime" ];
in
{
  # Forcibly disable Plymouth, so the encrypted bcachefs root can be unlocked
  boot.plymouth.enable = lib.mkForce false;

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
                mountOptions = [ "defaults" "umask=0077" ];
                mountpoint = "/boot";
                type = "filesystem";
              };
            };
            root = {
              size = "100%";
              content = {
                extraArgs = [ "-f" "--compression=lz4" "--discard" "--encrypted" ];
                format = "bcachefs";
                mountOptions = defaultBcachefsOpts;
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
