{ pkgs, username, ... }:
{
  environment.systemPackages = with pkgs; [
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
