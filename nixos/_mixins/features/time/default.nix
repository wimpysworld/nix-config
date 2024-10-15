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
      # https://github.com/NixOS/nixpkgs/issues/321121
      geoProviderUrl = "https://api.positon.xyz/v1/geolocate?key=test";
      submissionUrl = "https://api.positon.xyz/v2/geosubmit?key=test";
      submitData = false;
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
