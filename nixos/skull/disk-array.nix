# nix shell nixpkgs#gptfdisk
# sudo nix run github:nix-community/disko -- --mode zap_create_mount ./disk-array.nix
# Transcend MTS830S 4TB
#sda           8:0    0   3.7T  0 disk 
#sdb           8:16   0   3.7T  0 disk 
#sdc           8:32   0   3.7T  0 disk 
#sdd           8:48   0   3.7T  0 disk 

# WD Blue 2TB
#sde           8:64   0   1.8T  0 disk 
#sdf           8:80   0   1.8T  0 disk 
#sdg           8:96   0   1.8T  0 disk 
#sdh           8:112  0   1.8T  0 disk

# Transcend MTS830S 2TB (tbd)
#sd?
#sd?
#sd?
#sd?

{ disks ? [ "/dev/sda" "/dev/sdb" "/dev/sdc" "/dev/sdd" "/dev/sde" "/dev/sdf" "/dev/sdg" "/dev/sdh" ], ... }:
let
  defaultXfsOpts = [ "defaults" "relatime" "nodiratime" ];
in
{
  disko.devices = {
    disk = {
      sda = {
        type = "disk";
        device = builtins.elemAt disks 0;
        content = {
          type = "table";
          format = "gpt";
          partitions = [{
            name = "fours-sda";
            start = "0%";
            end = "100%";
            content = {
              type = "mdraid";
              name = "fours";
            };
          }];
        };
      };
      sdb = {
        type = "disk";
        device = builtins.elemAt disks 1;
        content = {
          type = "table";
          format = "gpt";
          partitions = [{
            name = "fours-sdb";
            start = "0%";
            end = "100%";
            content = {
              type = "mdraid";
              name = "fours";
            };
          }];
        };
      };
      sdc = {
        type = "disk";
        device = builtins.elemAt disks 2;
        content = {
          type = "table";
          format = "gpt";
          partitions = [{
            name = "fours-sdc";
            start = "0%";
            end = "100%";
            content = {
              type = "mdraid";
              name = "fours";
            };
          }];
        };
      };
      sdd = {
        type = "disk";
        device = builtins.elemAt disks 3;
        content = {
          type = "table";
          format = "gpt";
          partitions = [{
            name = "fours-sdd";
            start = "0%";
            end = "100%";
            content = {
              type = "mdraid";
              name = "fours";
            };
          }];
        };
      };
      sde = {
        type = "disk";
        device = builtins.elemAt disks 4;
        content = {
          type = "table";
          format = "gpt";
          partitions = [{
            name = "twos-sde";
            start = "0%";
            end = "100%";
            content = {
              type = "mdraid";
              name = "twos";
            };
          }];
        };
      };
      sdf = {
        type = "disk";
        device = builtins.elemAt disks 5;
        content = {
          type = "table";
          format = "gpt";
          partitions = [{
            name = "twos-sdf";
            start = "0%";
            end = "100%";
            content = {
              type = "mdraid";
              name = "twos";
            };
          }];
        };
      };
      sdg = {
        type = "disk";
        device = builtins.elemAt disks 6;
        content = {
          type = "table";
          format = "gpt";
          partitions = [{
            name = "twos-sdg";
            start = "0%";
            end = "100%";
            content = {
              type = "mdraid";
              name = "twos";
            };
          }];
        };
      };
      sdh = {
        type = "disk";
        device = builtins.elemAt disks 7;
        content = {
          type = "table";
          format = "gpt";
          partitions = [{
            name = "twos-sdh";
            start = "0%";
            end = "100%";
            content = {
              type = "mdraid";
              name = "twos";
            };
          }];
        };
      };
    };
    mdadm = {
      fours = {
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
              mountpoint = "/mnt/fours";
              mountOptions = defaultXfsOpts;
            };
          }];
        };
      };
      twos = {
        type = "mdadm";
        level = 6;
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
              mountpoint = "/mnt/twos";
              mountOptions = defaultXfsOpts;
            };
          }];
        };
      };
    };
  };
}
