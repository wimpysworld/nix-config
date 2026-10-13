# Framework laptop support. Gated on the "framework" host tag.
# Provides fan curve control via fw-fanctrl and the Framework embedded
# controller tooling for firmware, battery, and LED management.
{
  lib,
  pkgs,
  noughtyLib,
  ...
}:
lib.mkIf (noughtyLib.hostHasTag "framework") {
  # Fan curve control for Framework laptops.
  hardware.fw-fanctrl.enable = true;
  # The default "lazy" curve reaches 100% at 85 °C. This quieter curve
  # reaches 100% only at 95 °C.
  hardware.fw-fanctrl.config = {
    defaultStrategy = lib.mkDefault "quiet";
    strategyOnDischarging = lib.mkDefault "quiet";
    strategies.quiet = {
      fanSpeedUpdateFrequency = 5;
      movingAverageInterval = 30;
      speedCurve = [
        {
          temp = 0;
          speed = 15;
        }
        {
          temp = 50;
          speed = 15;
        }
        {
          temp = 65;
          speed = 25;
        }
        {
          temp = 75;
          speed = 40;
        }
        {
          temp = 85;
          speed = 60;
        }
        {
          temp = 95;
          speed = 100;
        }
      ];
    };
  };

  environment.systemPackages = with pkgs; [
    framework-tool
    framework-tool-tui
  ];

  # Grant the logged-in user access to the embedded controller so that
  # framework-tool works without sudo.
  services.udev.extraRules = ''
    KERNEL=="cros_ec", TAG+="uaccess"
  '';
}
