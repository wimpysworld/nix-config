{
  config,
  lib,
  noughtyLib,
  ...
}:
let
  inherit (config.noughty) host;
  username = config.noughty.user.name;
  isWorkHost = noughtyLib.hostHasTag "cg";
  forMartin = [ "martin" ];

  essentialExtensions = [
    "hdokiejnpimakedhajhdlcegeplioahd" # LastPass
  ];
  extraExtensions = [
    "cjpalhdlnbpafiamejdnhcphjbkeiagm" # uBlock Origin
    "lodbfhdipoipcjmlebjbgmmgekckhpfb" # Harper
    "mdjildafknihdffpkfmmpnpoiajfjnjd" # Consent-O-Matic
    "mnjggcdmjocbbbhaepdhchncahnbgone" # SponsorBlock for YouTube
    "gebbhagfogifgggkldgodflihgfeippi" # Return YouTube Dislike
    "fdpohaocaechififmbbbbbknoalclacl" # GoFullPage
    "dfjdfadcciciboknnahlhgonamhfgmhp" # Disable Automatic Gain Control
    "cdglnehniifkbagbbombnjghhcihifij" # Kagi
    "dpaefegpjhgeplnkomgbcmmlffkijbgp" # Kagi Summariser
    #"bkkmolkhemgaeaeggcmfbghljjjoofoh" # Catppuccin Mocha
    "lnjaiaapbakfhlbjenjkhffcdpoompki" # Catppuccin Web file explorer icons
    "clngdbkpkpeebahjckkjfobafhncgmne" # Stylus
    "mdpfkohgfpidohkakdbpmnngaocglmhl" # Disable Ctrl + Scroll Zoom
  ];
in
{
  imports = [ ./martin.nix ];
  config = lib.mkIf (host.is.workstation && !isWorkHost) {
    # TODO: Configure Microsoft Edge policy
    # - https://learn.microsoft.com/en-us/deployedge/microsoft-edge-policies
    # - https://github.com/M86xKC/edge-config/blob/main/policies.json
    programs = {
      chromium = {
        # Configures policies for Chromium, Chrome and Brave
        # - https://chromeenterprise.google/policies/
        # - chromium.enable just enables the Chromium policies.
        enable = true;
        extensions =
          if (lib.elem username forMartin) then
            essentialExtensions ++ extraExtensions
          else
            essentialExtensions;
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
          # Note: DefaultDownloadDirectory and DownloadDirectory removed as they conflict with PromptForDownloadLocation
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
        # Set initial browser preferences (user can change these later in settings)
        # - https://www.chromium.org/administrators/configuring-other-preferences/
        # browser.theme.system_theme values: 0 = default, 1 = GTK, 2 = Chromium
        initialPrefs = {
          browser.theme = {
            # Use system (GTK) theme colors
            #follows_system_colors = true;
            system_theme = 1;
          };
        };
      };
    };
  };
}
