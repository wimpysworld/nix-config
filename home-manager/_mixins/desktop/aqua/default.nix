{ lib, pkgs, ... }:
let
  inherit (pkgs.stdenv) isDarwin;
in
lib.mkIf isDarwin {
  targets.darwin = {
    currentHostDefaults = {
      NSGlobalDomain = {
        AppleLanguages = [ "en-GB" ];
        AppleLocale = "en_GB";
      };
      "com.apple.Safari" = {
        AutoFillCreditCardData = false;
        AutoFillFromAddressBook = false;
        AutoFillMiscellaneousForms = false;
        AutoFillPasswords = false;
        # Prevent Safari from opening ‘safe’ files automatically after downloading
        AutoOpenSafeDownloads = false;
        IncludeInternalDebugMenu = true;
        IncludeDevelopMenu = true;
        # Privacy: don’t send search queries to Apple
        SuppressSearchSuggestions = true;
        UniversalSearchEnabled = false;
        ShowFavoritesBar = false;
        ShowFullURLInSmartSearchField = true;
        ShowOverlayStatusBar = true;
        WarnAboutFraudulentWebsites = true;
        WebAutomaticSpellingCorrectionEnabled = false;
        WebContinuousSpellCheckingEnabled = true;
        WebKitDeveloperExtrasEnabledPreferenceKey = true;
        WebKitJavaEnabled = false;
        WebKitJavaScriptCanOpenWindowsAutomatically = false;
      };
    };
  };
}
