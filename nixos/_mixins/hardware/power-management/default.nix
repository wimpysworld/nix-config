{
  config,
  noughtyLib,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;
  isIntelCPU = config.hardware.cpu.intel.updateMicrocode;
  isThinkpad = noughtyLib.hostHasTag "thinkpad";
  # Framework workstations have no battery, so limit charging to the laptops.
  isFrameworkLaptop = noughtyLib.hostHasTag "framework" && host.is.laptop;
  desktopName = if builtins.isString host.desktop then host.desktop else "";
  waylandCompositors = (import ../../../../lib/wayland-compositors.nix).compositors;
  usePowerProfiles = builtins.hasAttr desktopName waylandCompositors;
  syncPowerProfileOnAc = host.is.laptop && usePowerProfiles;
  ppdAcPowerSync = pkgs.writeShellApplication {
    name = "ppd-ac-power-sync";
    runtimeInputs = [
      pkgs.coreutils
      config.services.power-profiles-daemon.package
    ];
    text = ''
      ac_online=0
      has_battery=0
      for supply in /sys/class/power_supply/*; do
        [ -r "$supply/type" ] || continue
        read -r supply_type < "$supply/type"
        case "$supply_type" in
          Battery)
            has_battery=1
            ;;
          Mains|USB)
            if [ -r "$supply/online" ]; then
              read -r online < "$supply/online"
              if [ "$online" = "1" ]; then
                ac_online=1
              fi
            fi
            ;;
        esac
      done

      if [ "$has_battery" = "1" ] && [ "$ac_online" = "0" ]; then
        powerprofilesctl set power-saver
      else
        powerprofilesctl set balanced
      fi
    '';
  };
  chargeThresholds = {
    start = 15;
    stop = 85;
  };
in
lib.mkIf (!host.is.iso) {
  # Power Management strategy:
  # - If a desktop environment is enabled the supports the power-profiles-daemon, then use the power profiles daemon.
  #   - Otherwise, use auto-cpufreq.
  # - If zramSwap is enabled, then disable power management features that conflict with zram.
  # - Always disable TLP and Powertop because they conflict with auto-cpufreq or agressively suspend USB devices
  # - Disable USB autosuspend on desktop workstations
  # - Enable thermald on Intel CPUs
  # - Thinkpads have a battery threshold charging via auto-cpufreq, and via a udev rule when
  #   auto-cpufreq is not running
  # - Framework laptops have a battery charge limit via a udev rule
  # - UPower acts on critical battery charge on workstations

  # Disable USB autosuspend on desktop always on power workstations
  boot.kernelParams = lib.optionals (!host.is.laptop) [ "usbcore.autosuspend=-1" ];

  powerManagement.powertop.enable = lib.mkDefault false;

  services = {
    auto-cpufreq = {
      enable = !usePowerProfiles && host.is.laptop;
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
          start_threshold = chargeThresholds.start;
          stop_threshold = chargeThresholds.stop;
        };
      };
    };
    # Only enable power-profiles-daemon if the desktop environment supports it
    power-profiles-daemon.enable = usePowerProfiles;
    # Only enable thermald on Intel CPUs
    thermald.enable = isIntelCPU;
    # Disable TLP because it conflicts with auto-cpufreq
    tlp.enable = lib.mkForce false;
    # Power off at critical battery charge. HybridSleep, the default, needs
    # hibernation, which this module disables when zram swap is enabled.
    # Desktops get UPower too, because WirePlumber warns when it is missing.
    # The default percentages (20 low, 5 critical, 2 action) are kept.
    upower = lib.mkIf host.is.workstation {
      enable = lib.mkDefault true;
      criticalPowerAction = lib.mkDefault "PowerOff";
    };
    # Apply the ThinkPad charge thresholds independently of auto-cpufreq. A udev
    # rule is used instead of a tmpfiles rule because thinkpad_acpi adds the
    # threshold attributes to the battery after it appears, and tmpfiles is not
    # ordered after module loading at boot. When the battery appears after
    # thinkpad_acpi, the attributes normally exist by the time the add event is handled.
    # When thinkpad_acpi loads after the battery, the kernel sends a change event
    # once the attributes exist, so the rule matches both. Later change events
    # rewrite the same values, which is harmless. The start threshold is written
    # first because the kernel rejects a start above the current stop and a stop
    # below the current start, and the firmware defaults keep the stop high.
    #
    # Framework laptops expose only the stop threshold, through the
    # framework_laptop module, so the battery charges again as soon as it
    # drops below the stop value. The same udev approach applies the limit at
    # every boot, which overrides the charge limit in the firmware setup.
    udev.extraRules =
      lib.optionalString isThinkpad ''
        ACTION=="add|change", SUBSYSTEM=="power_supply", KERNEL=="BAT*", TEST=="charge_control_start_threshold", ATTR{charge_control_start_threshold}="${toString chargeThresholds.start}", ATTR{charge_control_end_threshold}="${toString chargeThresholds.stop}"
      ''
      + lib.optionalString isFrameworkLaptop ''
        ACTION=="add|change", SUBSYSTEM=="power_supply", KERNEL=="BAT*", TEST=="charge_control_end_threshold", ATTR{charge_control_end_threshold}="${toString chargeThresholds.stop}"
      ''
      + lib.optionalString syncPowerProfileOnAc ''
        SUBSYSTEM=="power_supply", ATTR{online}=="0|1", RUN+="${pkgs.systemd}/bin/systemctl start --no-block power-profiles-ac-sync.service"
      '';
  };

  systemd.services.power-profiles-ac-sync = lib.mkIf syncPowerProfileOnAc {
    description = "Sync power-profiles-daemon profile with AC adapter state";
    after = [ "power-profiles-daemon.service" ];
    wants = [ "power-profiles-daemon.service" ];
    wantedBy = [
      "multi-user.target"
      "post-resume.target"
    ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${ppdAcPowerSync}/bin/ppd-ac-power-sync";
    };
  };

  # Disable hiberate, hybrid-sleep and suspend-then-hibernate when zram swap is enabled.
  systemd.targets.hibernate.enable = !config.zramSwap.enable;
  systemd.targets.hybrid-sleep.enable = !config.zramSwap.enable;
  systemd.targets.suspend-then-hibernate.enable = !config.zramSwap.enable;
}
