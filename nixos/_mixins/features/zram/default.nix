{
  config,
  lib,
  pkgs,
  ...
}:
let
  # Only enable zram swap if no swap devices are configured
  usezramSwap = builtins.length config.swapDevices == 0;
in
{
  # Keep zram swap (lz4) latency in check
  boot.kernel.sysctl = lib.mkIf usezramSwap { "vm.page-cluster" = 1; };

  # Enable Multi-Gen LRU:
  # - https://docs.kernel.org/next/admin-guide/mm/multigen_lru.html
  # - Inspired by: https://github.com/hakavlad/mg-lru-helper
  systemd.services."mglru" = lib.mkIf usezramSwap {
    enable = true;
    wantedBy = [ "basic.target" ];
    script = ''
      ${pkgs.coreutils-full}/bin/echo 1000 > /sys/kernel/mm/lru_gen/min_ttl_ms
    '';
    serviceConfig = {
      Type = "oneshot";
    };
    unitConfig = {
      ConditionPathExists = "/sys/kernel/mm/lru_gen/enabled";
      Description = "Configure Enable Multi-Gen LRU";
    };
  };

  # Enable zram
  # - https://github.com/ecdye/zram-config/blob/main/README.md#performance
  # - https://www.reddit.com/r/Fedora/comments/mzun99/new_zram_tuning_benchmarks/
  # - https://linuxreviews.org/Zram
  zramSwap = {
    algorithm = "lz4";
    enable = usezramSwap;
  };
}
