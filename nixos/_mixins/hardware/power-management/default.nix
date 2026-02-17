{
  config,
  hostname,
  isInstall,
  isLaptop,
  lib,
  ...
}:
let
  isIntelCPU = config.hardware.cpu.intel.updateMicrocode;
  isThinkpad =
    hostname == "tanis"
    || hostname == "felkor"
    || hostname == "sidious"
    || hostname == "shaa"
    || hostname == "atrius";
  usePowerProfiles = config.programs.hyprland.enable || config.programs.wayfire.enable;
in
lib.mkIf isInstall {
  # Power Management strategy:
  # - If a desktop environment is enabled the supports the power-profiles-daemon, then use the power profiles daemon.
  #   - Otherwise, use auto-cpufreq.
  # - If zramSwap is enabled, then disable power management features that conflict with zram.
  # - Always disable TLP and Powertop because they conflict with auto-cpufreq or agressively suspend USB devices
  # - Disable USB autosuspend on desktop workstations
  # - Enable thermald on Intel CPUs
  # - Thinkpads have a battery threshold charging via auto-cpufreq

  # Disable USB autosuspend on desktop always on power workstations
  boot.kernelParams = lib.optionals (!isLaptop) [ "usbcore.autosuspend=-1" ];

  powerManagement.powertop.enable = lib.mkDefault false;

  services = {
    auto-cpufreq = {
      enable = !usePowerProfiles && isLaptop;
      settings = {
        battery = {
          governor = "powersave";
          platform_profile = "low-power";
          turbo = "never";
        };
        charger = {
          governor = "performance";
          platform_profile = "balanced";
          turbo = "auto";
        };
        battery = {
          enable_thresholds = isThinkpad;
          start_threshold = 15;
          stop_threshold = 85;
        };
      };
    };
    # Only enable power-profiles-daemon if the desktop environment supports it
    power-profiles-daemon.enable = usePowerProfiles;
    # Only enable thermald on Intel CPUs
    thermald.enable = isIntelCPU;
    # Disable TLP because it conflicts with auto-cpufreq
    tlp.enable = lib.mkForce false;
  };

  # Disable hiberate, hybrid-sleep and suspend-then-hibernate when zram swap is enabled.
  systemd.targets.hibernate.enable = !config.zramSwap.enable;
  systemd.targets.hybrid-sleep.enable = !config.zramSwap.enable;
  systemd.targets.suspend-then-hibernate.enable = !config.zramSwap.enable;
}
