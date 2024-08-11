{ config, hostname, isInstall, lib, pkgs, ... }:
let
  isIntelCPU = config.hardware.cpu.intel.updateMicrocode;
  isLaptop = hostname != "vader" && hostname != "phasma" && hostname != "revan";
  GNOMEIsenabled = config.services.xserver.desktopManager.gnome.enable == true;
  isThinkpad = hostname == "tanis" || hostname == "sidious"|| hostname == "shaa";
in
lib.mkIf isInstall {
  # Install Battery Threshold GNOME extensions for Thinkpads
  environment.systemPackages = with pkgs; lib.optionals (isThinkpad && GNOMEIsenabled) [
    gnomeExtensions.thinkpad-battery-threshold
  ];
  programs = {
    auto-cpufreq = {
      enable = (!GNOMEIsenabled && isLaptop);
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
  };
  services = {
    # Only enable power-profiles-daemon if GNOME is enabled
    power-profiles-daemon.enable = (GNOMEIsenabled && isLaptop);
    # Only enable thermald on Intel CPUs
    thermald.enable = isIntelCPU;
    # Disable TLP because it conflicts with auto-cpufreq
    tlp.enable = lib.mkForce false;
  };
}
