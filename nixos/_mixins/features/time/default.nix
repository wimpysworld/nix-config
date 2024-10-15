{
  hostname,
  lib,
  ...
}:
let
  isServer = hostname == "malak" || hostname == "revan";
  useGeoclue = !isServer;
in
{
  location = {
    provider = "geoclue2";
  };

  services = {
    automatic-timezoned.enable = useGeoclue;
    geoclue2 = {
      enable = true;
      enableNmea = false;
      # https://github.com/NixOS/nixpkgs/issues/321121
      geoProviderUrl = "https://www.googleapis.com/geolocation/v1/geolocate?key=AIzaSyDwr302FpOSkGRpLlUpPThNTDPbXcIn_FM";
    };
    localtimed.enable = useGeoclue;
  };

  # Prevent "Failed to open /etc/geoclue/conf.d/:" errors
  systemd.tmpfiles.rules = [
    "d /etc/geoclue/conf.d 0755 root root"
  ];

  time = {
    hardwareClockInLocalTime = true;
    timeZone = lib.mkIf isServer "UTC";
  };
}
