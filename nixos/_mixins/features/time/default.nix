_: {
  location = {
    provider = "geoclue2";
  };

  services = {
    automatic-timezoned.enable = true;
    geoclue2 = {
      enable = true;
      # https://github.com/NixOS/nixpkgs/issues/321121
      geoProviderUrl = "https://beacondb.net/v1/geolocate";
      submissionNick = "wimpress.io";
      submissionUrl = "https://beacondb.net/v2/geosubmit";
      submitData = true;
    };
    localtimed.enable = true;
  };

  time = {
    hardwareClockInLocalTime = true;
  };
}
