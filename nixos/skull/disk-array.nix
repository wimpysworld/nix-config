# nix shell nixpkgs#gptfdisk

# sudo nix run github:nix-community/disko -- --mode zap_create_mount ./disk-array.nix
# sudo nix run github:nix-community/disko -- --mode format ./disk-array.nix
# sudo nix run github:nix-community/disko -- --mode mount ./disk-array.nix

# Top Card: 4x Transcend MTS830S 2TB
#/dev/disk/by-id/ata-TS2TMTS830S_I021610007
#/dev/disk/by-id/ata-TS2TMTS830S_I021610011
#/dev/disk/by-id/ata-TS2TMTS830S_I021610027
#/dev/disk/by-id/ata-TS2TMTS830S_I021610056

# Middle Card: 4x Transcend MTS830S 4TB
#/dev/disk/by-id/ata-TS4TMTS830S_H738980002
#/dev/disk/by-id/ata-TS4TMTS830S_H760910070
#/dev/disk/by-id/ata-TS4TMTS830S_H760910071
#/dev/disk/by-id/ata-TS4TMTS830S_H760910072

# Bottom Card: 4x WD Blue 2TB
#/dev/disk/by-id/ata-WDC_WDS200T2B0B-00YS70_23024Z440206
#/dev/disk/by-id/ata-WDC_WDS200T2B0B-00YS70_23024Z445606
#/dev/disk/by-id/ata-WDC_WDS200T2B0B-00YS70_23024Z449709
#/dev/disk/by-id/missing

{ disks ? [ "/dev/disk/by-id/ata-TS4TMTS830S_H738980002"
            "/dev/disk/by-id/ata-TS4TMTS830S_H760910070"
            "/dev/disk/by-id/ata-TS4TMTS830S_H760910071"
            "/dev/disk/by-id/ata-TS4TMTS830S_H760910072"
            "/dev/disk/by-id/ata-TS2TMTS830S_I021610007"
            "/dev/disk/by-id/ata-TS2TMTS830S_I021610011"
            "/dev/disk/by-id/ata-TS2TMTS830S_I021610027"
            "/dev/disk/by-id/ata-TS2TMTS830S_I021610056"
            "/dev/disk/by-id/ata-WDC_WDS200T2B0B-00YS70_23024Z440206"
            "/dev/disk/by-id/ata-WDC_WDS200T2B0B-00YS70_23024Z445606"
            "/dev/disk/by-id/ata-WDC_WDS200T2B0B-00YS70_23024Z449709"
            #/dev/disk/by-id/missing
          ], ... }:
let
  defaultXfsOpts = [ "defaults" "relatime" "nodiratime" ];
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
          partitions = [{
            name = "TS4-1";
            start = "0%";
            end = "100%";
            content = {
              type = "mdraid";
              name = "TS4";
            };
          }];
        };
      };
      TS4-2 = {
        type = "disk";
        device = builtins.elemAt disks 1;
        content = {
          type = "table";
          format = "gpt";
          partitions = [{
            name = "TS4-2";
            start = "0%";
            end = "100%";
            content = {
              type = "mdraid";
              name = "TS4";
            };
          }];
        };
      };
      TS4-3 = {
        type = "disk";
        device = builtins.elemAt disks 2;
        content = {
          type = "table";
          format = "gpt";
          partitions = [{
            name = "TS3-3";
            start = "0%";
            end = "100%";
            content = {
              type = "mdraid";
              name = "TS4";
            };
          }];
        };
      };
      TS4-4 = {
        type = "disk";
        device = builtins.elemAt disks 3;
        content = {
          type = "table";
          format = "gpt";
          partitions = [{
            name = "TS4-4";
            start = "0%";
            end = "100%";
            content = {
              type = "mdraid";
              name = "TS4";
            };
          }];
        };
      };
      TS2-1 = {
        type = "disk";
        device = builtins.elemAt disks 4;
        content = {
          type = "table";
          format = "gpt";
          partitions = [{
            name = "TS2-1";
            start = "0%";
            end = "100%";
            content = {
              type = "mdraid";
              name = "TS2";
            };
          }];
        };
      };
      TS2-2 = {
        type = "disk";
        device = builtins.elemAt disks 5;
        content = {
          type = "table";
          format = "gpt";
          partitions = [{
            name = "TS2-2";
            start = "0%";
            end = "100%";
            content = {
              type = "mdraid";
              name = "TS2";
            };
          }];
        };
      };
      TS2-3 = {
        type = "disk";
        device = builtins.elemAt disks 6;
        content = {
          type = "table";
          format = "gpt";
          partitions = [{
            name = "TS2-3";
            start = "0%";
            end = "100%";
            content = {
              type = "mdraid";
              name = "TS2";
            };
          }];
        };
      };
      TS2-4 = {
        type = "disk";
        device = builtins.elemAt disks 7;
        content = {
          type = "table";
          format = "gpt";
          partitions = [{
            name = "TS2-4";
            start = "0%";
            end = "100%";
            content = {
              type = "mdraid";
              name = "TS2";
            };
          }];
        };
      };
      WDS2-1 = {
        type = "disk";
        device = builtins.elemAt disks 8;
        content = {
          type = "table";
          format = "gpt";
          partitions = [{
            name = "WDS2-1";
            start = "0%";
            end = "100%";
            content = {
              type = "mdraid";
              name = "WDS2";
            };
          }];
        };
      };
      WDS2-2 = {
        type = "disk";
        device = builtins.elemAt disks 9;
        content = {
          type = "table";
          format = "gpt";
          partitions = [{
            name = "WDS2-2";
            start = "0%";
            end = "100%";
            content = {
              type = "mdraid";
              name = "WDS2";
            };
          }];
        };
      };
      WDS2-3 = {
        type = "disk";
        device = builtins.elemAt disks 10;
        content = {
          type = "table";
          format = "gpt";
          partitions = [{
            name = "WDS2-3";
            start = "0%";
            end = "100%";
            content = {
              type = "mdraid";
              name = "WDS2";
            };
          }];
        };
      };
      #WDS2-4 = {
      #  type = "disk";
      #  device = builtins.elemAt disks 11;
      #  content = {
      #    type = "table";
      #    format = "gpt";
      #    partitions = [{
      #      name = "WDS2-4";
      #      start = "0%";
      #      end = "100%";
      #      content = {
      #        type = "mdraid";
      #        name = "WDS2";
      #      };
      #    }];
      #  };
      #};
    };
    mdadm = {
      TS4 = {
        type = "mdadm";
        level = 5;
        content = {
          type = "table";
          format = "gpt";
          partitions = [{
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
          }];
        };
      };
      TS2 = {
        type = "mdadm";
        level = 5;
        content = {
          type = "table";
          format = "gpt";
          partitions = [{
            name = "primary";
            start = "0%";
            end = "100%";
            content = {
              type = "filesystem";
              # Overwirte the existing filesystem
              extraArgs = [ "-f" ];
              format = "xfs";
              mountpoint = "/mnt/TS2";
              mountOptions = defaultXfsOpts;
            };
          }];
        };
      };
      WDS2 = {
        type = "mdadm";
        # TODO: Temporary while testing a drive is missing
        level = 0;
        content = {
          type = "table";
          format = "gpt";
          partitions = [{
            name = "primary";
            start = "0%";
            end = "100%";
            content = {
              type = "filesystem";
              # Overwirte the existing filesystem
              extraArgs = [ "-f" ];
              format = "xfs";
              mountpoint = "/mnt/WDS2";
              mountOptions = defaultXfsOpts;
            };
          }];
        };
      };
    };
  };
}
