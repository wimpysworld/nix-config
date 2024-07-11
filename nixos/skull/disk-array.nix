# nix shell nixpkgs#gptfdisk

# Disk zipper `skull-wipe-array.sh` in the scripts directory
# sudo nix run github:nix-community/disko -- --mode zap_create_mount ./disk-array.nix
# sudo nix run github:nix-community/disko -- --mode format ./disk-array.nix
# sudo nix run github:nix-community/disko -- --mode mount ./disk-array.nix

# Simple sequential write test
# echo 3 | sudo tee /proc/sys/vm/drop_caches
# dd if=/dev/zero of=./test bs=1M count=10240 conv=fdatasync,notrunc status=progress

# This is becuase is turned out one of the PCI adapters was faulty and I was chasing my tail for a while.
# Find faulty ATA
# dmesg | grep FPDMA | cut -d']' -f2- | sort -u'
# Resolve ATA to drive
# ata=3; ls -l /sys/block/sd* | grep $(grep $ata /sys/class/scsi_host/host*/unique_id | awk -F'/' '{print $5}')')
# ls -l /sys/block/sd* | sed 's/.*\(sd.*\) -.*\(ata.*\)\/h.*/\2 => \1/'
# Watch for errors with: dmesg -wH

# Middle Card (x8): 4x Transcend MTS830S 4TB
#/dev/disk/by-id/ata-TS4TMTS830S_H986540082 (SATA-1)
#/dev/disk/by-id/ata-TS4TMTS830S_H986540080 (SATA-2)
#/dev/disk/by-id/ata-TS4TMTS830S_H986540076 (SATA-3)
#/dev/disk/by-id/ata-TS4TMTS830S_H986540074 (SATA-4)

# Bottom Card (x8): 4x Transcend MTS830S 4TB
#/dev/disk/by-id/ata-TS4TMTS830S_H738980002 (SATA-1)
#/dev/disk/by-id/ata-TS4TMTS830S_H760910071 (SATA-2)
#/dev/disk/by-id/ata-TS4TMTS830S_H760910070 (SATA-3)
#/dev/disk/by-id/ata-TS4TMTS830S_H760910072 (SATA-4)

{
  disks ? [
    "/dev/disk/by-id/ata-TS4TMTS830S_H986540082"
    "/dev/disk/by-id/ata-TS4TMTS830S_H986540080"
    "/dev/disk/by-id/ata-TS4TMTS830S_H986540076"
    "/dev/disk/by-id/ata-TS4TMTS830S_H986540074"
    "/dev/disk/by-id/ata-TS4TMTS830S_H738980002"
    "/dev/disk/by-id/ata-TS4TMTS830S_H760910071"
    "/dev/disk/by-id/ata-TS4TMTS830S_H760910070"
    "/dev/disk/by-id/ata-TS4TMTS830S_H760910072"
  ],
  ...
}:
let
  defaultXfsOpts = [
    "defaults"
    "relatime"
    "nodiratime"
  ];
in
{
  disko.devices = {
    disk = {
      TS4-1 = {
        type = "disk";
        device = builtins.elemAt disks 0;
        content = {
          type = "table";
          format = "gpt";
          partitions = [
            {
              name = "MID-SATA1";
              start = "0%";
              end = "100%";
              content = {
                type = "mdraid";
                name = "TS4";
              };
            }
          ];
        };
      };
      TS4-2 = {
        type = "disk";
        device = builtins.elemAt disks 1;
        content = {
          type = "table";
          format = "gpt";
          partitions = [
            {
              name = "MID-SATA2";
              start = "0%";
              end = "100%";
              content = {
                type = "mdraid";
                name = "TS4";
              };
            }
          ];
        };
      };
      TS4-3 = {
        type = "disk";
        device = builtins.elemAt disks 2;
        content = {
          type = "table";
          format = "gpt";
          partitions = [
            {
              name = "MID-SATA3";
              start = "0%";
              end = "100%";
              content = {
                type = "mdraid";
                name = "TS4";
              };
            }
          ];
        };
      };
      TS4-4 = {
        type = "disk";
        device = builtins.elemAt disks 3;
        content = {
          type = "table";
          format = "gpt";
          partitions = [
            {
              name = "MID-SATA4";
              start = "0%";
              end = "100%";
              content = {
                type = "mdraid";
                name = "TS4";
              };
            }
          ];
        };
      };
      TS4-5 = {
        type = "disk";
        device = builtins.elemAt disks 4;
        content = {
          type = "table";
          format = "gpt";
          partitions = [
            {
              name = "BOT-SATA1";
              start = "0%";
              end = "100%";
              content = {
                type = "mdraid";
                name = "TS4";
              };
            }
          ];
        };
      };
      TS4-6 = {
        type = "disk";
        device = builtins.elemAt disks 5;
        content = {
          type = "table";
          format = "gpt";
          partitions = [
            {
              name = "BOT-SATA2";
              start = "0%";
              end = "100%";
              content = {
                type = "mdraid";
                name = "TS4";
              };
            }
          ];
        };
      };
      TS4-7 = {
        type = "disk";
        device = builtins.elemAt disks 6;
        content = {
          type = "table";
          format = "gpt";
          partitions = [
            {
              name = "BOT-SATA3";
              start = "0%";
              end = "100%";
              content = {
                type = "mdraid";
                name = "TS4";
              };
            }
          ];
        };
      };
      TS4-8 = {
        type = "disk";
        device = builtins.elemAt disks 7;
        content = {
          type = "table";
          format = "gpt";
          partitions = [
            {
              name = "BOT-SATA4";
              start = "0%";
              end = "100%";
              content = {
                type = "mdraid";
                name = "TS4";
              };
            }
          ];
        };
      };
    };
    mdadm = {
      TS4 = {
        type = "mdadm";
        level = 6;
        content = {
          type = "table";
          format = "gpt";
          partitions = [
            {
              name = "primary";
              start = "0%";
              end = "100%";
              content = {
                type = "filesystem";
                # Overwirte the existing filesystem
                extraArgs = [ "-f" ];
                format = "xfs";
                mountpoint = "/mnt/TS4";
                mountOptions = defaultXfsOpts;
              };
            }
          ];
        };
      };
    };
  };
}
