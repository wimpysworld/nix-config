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
  # Fan curve control for Framework laptops. The default "lazy" strategy
  # suits both the Framework 13 and Framework 16.
  hardware.fw-fanctrl.enable = true;

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
