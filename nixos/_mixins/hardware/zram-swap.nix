{ ... }: {
  boot = {
    # Keep zram swap (lz4) latency in check
    kernel.sysctl = {
      "vm.page-cluster" = 1;
    };
  };
  # Disable hiberate and hybrid-sleep when using zram.
  systemd.targets.hibernate.enable = false;
  systemd.targets.hybrid-sleep.enable = false;
  # Enable zram
  # - https://github.com/ecdye/zram-config/blob/main/README.md#performance
  # - https://www.reddit.com/r/Fedora/comments/mzun99/new_zram_tuning_benchmarks/
  # - https://linuxreviews.org/Zram
  zramSwap = {
    algorithm = "lz4";
    enable = true;
  };
}
