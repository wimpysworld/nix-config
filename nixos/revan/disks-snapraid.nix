# Slot 1 (PCIEX16):  Sedna PCIe Quad M.2 SATA III (6G) SSD Adapter (12TB) - LIVE
#/dev/disk/by-id/ata-TS2TMTS830S_I121590039              - data_02   (TV)
#/dev/disk/by-id/ata-TS2TMTS830S_I121590044              - data_03   (Data)
#/dev/disk/by-id/ata-TS4TMTS830S_H738980002              - data_01   (Films)
#/dev/disk/by-id/ata-TS4TMTS830S_H760910071              - parity_01

# Slot 2 (PCIEX1_1): Sedna PCIe Dual M.2 SATA III (6G) SSD Adapter (4TB)  - LIVE
#/dev/disk/by-id/ata-WDC_WDS200T2B0B-00YS70_23024Y443104 - data_04   (TV)
#/dev/disk/by-id/ata-WDC_WDS200T2B0B-00YS70_23024Z445606 - data_05   (Data)

# Slot 5 (PCIEX4):   Sedna PCIe Quad M.2 SATA III (6G) SSD Adapter (12TB) - LIVE
#/dev/disk/by-id/ata-TS2TMTS830S_I021610007              - data_07   (TV)
#/dev/disk/by-id/ata-TS2TMTS830S_I021610056              - data_08   (Data)
#/dev/disk/by-id/ata-TS4TMTS830S_H760910070              - parity_02
#/dev/disk/by-id/ata-TS4TMTS830S_H760910072              - data_06   (Films)

# See ./disks-snapraid-extra.nix
# Slot 4 (PCIEX1_2): Sedna PCIe Dual M.2 SATA III (6G) SSD Adapter (4TB)  - LIVE
#/dev/disk/by-id/ata-WDC_WDS200T2B0B-00YS70_23024Z440206 - data_09   (Films)
#/dev/disk/by-id/ata-WDC_WDS200T2B0B-00YS70_23024Z449709 - data_10   (TV)

# Utilisation: April 6th 2026
# Films: 4TB Free
# TV:    5TB Free
# Data:  6TB Free

_: {
  disko.devices = {
    disk = {
      s1_TS4_071 = {
        type = "disk";
        device = "/dev/disk/by-id/ata-TS4TMTS830S_H760910071";
        content = {
          type = "gpt";
          partitions = {
            p01 = {
              size = "100%";
              content = {
                type = "filesystem";
                format = "xfs";
                mountpoint = "/mnt/parity_01";
                mountOptions = [ "defaults" ];
              };
            };
          };
        };
      };
      s1_TS4_002 = {
        type = "disk";
        device = "/dev/disk/by-id/ata-TS4TMTS830S_H738980002";
        content = {
          type = "gpt";
          partitions = {
            d01 = {
              size = "100%";
              content = {
                type = "filesystem";
                format = "xfs";
                mountpoint = "/mnt/data_01";
                mountOptions = [ "defaults" ];
              };
            };
          };
        };
      };
      s1_TS2_039 = {
        type = "disk";
        device = "/dev/disk/by-id/ata-TS2TMTS830S_I121590039";
        content = {
          type = "gpt";
          partitions = {
            d02 = {
              size = "100%";
              content = {
                type = "filesystem";
                format = "xfs";
                mountpoint = "/mnt/data_02";
                mountOptions = [ "defaults" ];
              };
            };
          };
        };
      };
      s1_TS2_044 = {
        type = "disk";
        device = "/dev/disk/by-id/ata-TS2TMTS830S_I121590044";
        content = {
          type = "gpt";
          partitions = {
            d03 = {
              size = "100%";
              content = {
                type = "filesystem";
                format = "xfs";
                mountpoint = "/mnt/data_03";
                mountOptions = [ "defaults" ];
              };
            };
          };
        };
      };
      s2_WDC2_104 = {
        type = "disk";
        device = "/dev/disk/by-id/ata-WDC_WDS200T2B0B-00YS70_23024Y443104";
        content = {
          type = "gpt";
          partitions = {
            d04 = {
              size = "100%";
              content = {
                type = "filesystem";
                format = "xfs";
                mountpoint = "/mnt/data_04";
                mountOptions = [ "defaults" ];
              };
            };
          };
        };
      };
      s2_WDC2_606 = {
        type = "disk";
        device = "/dev/disk/by-id/ata-WDC_WDS200T2B0B-00YS70_23024Z445606";
        content = {
          type = "gpt";
          partitions = {
            d05 = {
              size = "100%";
              content = {
                type = "filesystem";
                format = "xfs";
                mountpoint = "/mnt/data_05";
                mountOptions = [ "defaults" ];
              };
            };
          };
        };
      };
      s5_TS4_070 = {
        type = "disk";
        device = "/dev/disk/by-id/ata-TS4TMTS830S_H760910070";
        content = {
          type = "gpt";
          partitions = {
            p02 = {
              size = "100%";
              content = {
                type = "filesystem";
                format = "xfs";
                mountpoint = "/mnt/parity_02";
                mountOptions = [ "defaults" ];
              };
            };
          };
        };
      };
      s5_TS4_072 = {
        type = "disk";
        device = "/dev/disk/by-id/ata-TS4TMTS830S_H760910072";
        content = {
          type = "gpt";
          partitions = {
            d06 = {
              size = "100%";
              content = {
                type = "filesystem";
                format = "xfs";
                mountpoint = "/mnt/data_06";
                mountOptions = [ "defaults" ];
              };
            };
          };
        };
      };
      s5_TS2_007 = {
        type = "disk";
        device = "/dev/disk/by-id/ata-TS2TMTS830S_I021610007";
        content = {
          type = "gpt";
          partitions = {
            d07 = {
              size = "100%";
              content = {
                type = "filesystem";
                format = "xfs";
                mountpoint = "/mnt/data_07";
                mountOptions = [ "defaults" ];
              };
            };
          };
        };
      };
      s5_TS2_056 = {
        type = "disk";
        device = "/dev/disk/by-id/ata-TS2TMTS830S_I021610056";
        content = {
          type = "gpt";
          partitions = {
            d08 = {
              size = "100%";
              content = {
                type = "filesystem";
                format = "xfs";
                mountpoint = "/mnt/data_08";
                mountOptions = [ "defaults" ];
              };
            };
          };
        };
      };
    };
  };
}
