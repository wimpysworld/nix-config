# Slot 4 (PCIEX1_2): Sedna PCIe Dual M.2 SATA III (6G) SSD Adapter (4TB)  - LIVE
#/dev/disk/by-id/ata-WDC_WDS200T2B0B-00YS70_23024Z440206 - data_09   (Films)
#/dev/disk/by-id/ata-WDC_WDS200T2B0B-00YS70_23024Z449709 - data_10   (TV)

_: {
  disko.devices = {
    disk = {
      s4_WDC2_206 = {
        type = "disk";
        device = "/dev/disk/by-id/ata-WDC_WDS200T2B0B-00YS70_23024Z440206";
        content = {
          type = "gpt";
          partitions = {
            d04 = {
              size = "100%";
              content = {
                type = "filesystem";
                format = "xfs";
                mountpoint = "/mnt/data_09";
                mountOptions = [ "defaults" ];
              };
            };
          };
        };
      };
      s4_WDC2_709 = {
        type = "disk";
        device = "/dev/disk/by-id/ata-WDC_WDS200T2B0B-00YS70_23024Z449709";
        content = {
          type = "gpt";
          partitions = {
            d05 = {
              size = "100%";
              content = {
                type = "filesystem";
                format = "xfs";
                mountpoint = "/mnt/data_10";
                mountOptions = [ "defaults" ];
              };
            };
          };
        };
      };
    };
  };
}
