{ lib, pkgs, ... }:
let
  inherit (pkgs.stdenv) isDarwin;
in
lib.mkIf isDarwin {
  # Darwin specific configuration
  targets.darwin = {
    currentHostDefaults = {
      NSGlobalDomain = {
        AppleLanguages = [ "en-GB" ];
        AppleLocale = "en_GB";
        AppleMeasurementUnits = "Centimeters";
        AppleMetricUnits = true;
        AppleTemperatureUnit = "Celsius";
        NSAutomaticCapitalizationEnabled = false;
        NSAutomaticDashSubstitutionEnabled = false;
        NSAutomaticPeriodSubstitutionEnabled = false;
        NSAutomaticQuoteSubstitutionEnabled = false;
        NSAutomaticSpellingCorrectionEnabled = false;
      };
      "com.apple.Safari" = {
        AutoFillCreditCardData = false;
        AutoFillPasswords = false;
        AutoOpenSafeDownloads = false;
        ShowOverlayStatusBar = true;
      };
      "com.apple.desktopservices" = {
        DSDontWriteNetworkStores = true;
        DSDontWriteUSBStores = true;
      };
      "com.apple.dock" = {
        size-immutable = true;
        tilesize = 64;
      };
      "com.apple.controlcenter" = {
        BatteryShowPercentage = true;
      };
    };
    search = "Google";
  };
}
