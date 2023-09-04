{ desktop, pkgs, username, ... }:
{
  environment.systemPackages = with pkgs; [ ] ++ lib.optionals (desktop != null) [
    polychromatic
  ];

  hardware = {
    openrazer = {
      enable = true;
      devicesOffOnScreensaver = false;
      keyStatistics = true;
      mouseBatteryNotifier = true;
      syncEffectsEnabled = true;
      users = [ "${username}" ];
    };
  };
}
