{ desktop, hostname, lib, pkgs, username, ... }:
let
  isInstall = if (builtins.substring 0 4 hostname != "iso-") then true else false;
in
{
  imports = lib.optional (builtins.pathExists (./. + "/${username}.nix")) ./${username}.nix;

  environment.systemPackages = with pkgs; lib.optionals (isInstall) [
    (chromium.override { enableWideVine = true; })
  ];

  # TODO: Configure Microsoft Edge policy
  # - https://learn.microsoft.com/en-us/deployedge/microsoft-edge-policies
  # - https://github.com/M86xKC/edge-config/blob/main/policies.json
  programs = {
    chromium = {
      # Configures policies for Chromium, Chrome and Brave
      # - https://chromeenterprise.google/policies/
      # - chromium.enable just enables the Chromium policies.
      enable = isInstall;
      extensions = [
        "hdokiejnpimakedhajhdlcegeplioahd" # LastPass
      ];
      extraOpts = {
        # Misc; privacy and data collection prevention
        "BrowserNetworkTimeQueriesEnabled" = false;
        "DeviceMetricsReportingEnabled" = false;
        "DomainReliabilityAllowed" = false;
        "FeedbackSurveysEnabled" = false;
        "MetricsReportingEnabled" = false;
        "SpellCheckServiceEnabled" = false;
        # Misc; DNS
        "BuiltInDnsClientEnabled" = false;
        # Misc; Tabs
        "NTPCardsVisible" = false;
        "NTPCustomBackgroundEnabled" = false;
        "NTPMiddleSlotAnnouncementVisible" = false;
        # Misc; Downloads
        "DefaultDownloadDirectory" = "/home/${username}/Downloads";
        "DownloadDirectory" = "/home/${username}/Downloads";
        "PromptForDownloadLocation" = true;
        # Misc
        "AllowSystemNotifications" = true;
        "AutofillAddressEnabled" = false;
        "AutofillCreditCardEnabled" = false;
        "BackgroundModeEnabled" = false;
        "BookmarkBarEnabled" = false;
        "BrowserAddPersonEnabled" = true;
        "BrowserLabsEnabled" = false;
        "PromotionalTabsEnabled" = false;
        "ShoppingListEnabled" = false;
        "ShowFullUrlsInAddressBar" = true;
        "SpellcheckEnabled" = true;
        "SpellcheckLanguage" = [
          "en-GB"
          "en-US"
        ];
        # Cloud Reporting
        "CloudReportingEnabled" = false;
        "CloudProfileReportingEnabled" = false;
        # Content settings
        "DefaultGeolocationSetting" = 3;
        "DefaultImagesSetting" = 1;
        "DefaultPopupsSetting" = 1;
        "DefaultSearchProviderEnabled" = true;
        # Generative AI; these settings disable the AI features to prevent data collection
        "CreateThemesSettings" = 2;
        "DevToolsGenAiSettings" = 2;
        "GenAILocalFoundationalModelSettings" = 1;
        "HelpMeWriteSettings" = 2;
        "TabOrganizerSettings" = 2;
        # Network
        "ZstdContentEncodingEnabled" = true;
        # Password manager
        "PasswordDismissCompromisedAlertEnabled" = true;
        "PasswordLeakDetectionEnabled" = false;
        "PasswordManagerEnabled" = false;
        "PasswordSharingEnabled" = false;
        # Printing
        "PrintingPaperSizeDefault" = "iso_a4_210x297mm";
        # Related Website Sets
        "RelatedWebsiteSetsEnabled" = false;
        # Safe Browsing
        "SafeBrowsingExtendedReportingEnabled" = false;
        "SafeBrowsingProtectionLevel" = 1;
        "SafeBrowsingProxiedRealTimeChecksAllowed" = false;
        "SafeBrowsingSurveysEnabled" = false;
        # Startup, Home and New Tab Page
        "HomePageIsNewTabPage" = true;
        "RestoreOnStartup" = 1;
        "ShowHomeButton" = false;
      };
    };
  };
}
