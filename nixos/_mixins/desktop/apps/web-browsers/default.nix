{
  isInstall,
  lib,
  pkgs,
  username,
  ...
}:
let
  installFor = [ "martin" ];
in
{
  imports = lib.optional (builtins.pathExists (./. + "/${username}.nix")) ./${username}.nix;
  environment.systemPackages =
    with pkgs;
    lib.optionals isInstall [
      google-chrome
      microsoft-edge
    ]
    ++ lib.optionals (builtins.elem username installFor && isInstall) [
      brave
      chromium
      wavebox
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
    # - https://mozilla.github.io/policy-templates/
    firefox = {
      enable = true;
      languagePacks = [
        "en-GB"
        "en-US"
      ];
      package = pkgs.firefox;
      preferences = {
        "browser.crashReports.unsubmittedCheck.autoSubmit2" = false;
        "browser.crashReports.unsubmittedCheck.enabled" = false;
        "browser.fixup.dns_first_for_single_words" = false;
        "browser.newtab.extensionControlled" = true;
        "browser.search.update" = true;
        "browser.tabs.crashReporting.sendReport" = false;
        "browser.urlbar.suggest.bookmark" = false;
        "browser.urlbar.suggest.history" = true;
        "browser.urlbar.suggest.openpage" = false;
        "browser.tabs.warnOnClose" = false;
        "browser.urlbar.update2.engineAliasRefresh" = true;
        "datareporting.policy.dataSubmissionPolicyBypassNotification" = true;
        "dom.disable_window_flip" = true;
        "dom.disable_window_move_resize" = false;
        "dom.event.contextmenu.enabled" = true;
        "dom.reporting.crash.enabled" = false;
        "extensions.getAddons.showPane" = false;
        "media.gmp-gmpopenh264.enabled" = true;
        "media.gmp-widevinecdm.enabled" = true;
        "places.history.enabled" = true;
        "security.ssl.errorReporting.enabled" = false;
        "widget.use-xdg-desktop-portal.file-picker" = 1;
      };
      preferencesStatus = "default";
      policies = {
        "AutofillAddressEnabled" = false;
        "AutofillCreditCardEnabled" = false;
        "CaptivePortal" = true;
        "Cookies" = {
          "AcceptThirdParty" = "from-visited";
          "Behavior" = "reject-tracker";
          "BehaviorPrivateBrowsing" = "reject-tracker";
          "RejectTracker" = true;
        };
        "DisableAppUpdate" = true;
        "DisableDefaultBrowserAgent" = true;
        "DisableFirefoxStudies" = true;
        "DisableFormHistory" = true;
        "DisablePocket" = true;
        "DisableProfileImport" = true;
        "DisableTelemetry" = true;
        "DisableSetDesktopBackground" = true;
        "DisplayBookmarksToolbar" = "never";
        "DisplayMenuBar" = "default-off";
        "DNSOverHTTPS" = {
          "Enabled" = false;
        };
        "DontCheckDefaultBrowser" = true;
        "EnableTrackingProtection" = {
          "Value" = false;
          "Locked" = false;
          "Cryptomining" = true;
          "EmailTracking" = true;
          "Fingerprinting" = true;
        };
        "EncryptedMediaExtensions" = {
          "Enabled" = true;
          "Locked" = true;
        };
        # Check about:support for extension/add-on ID strings.
        ExtensionSettings = {
          "support@lastpass.com" = {
            install_url = "https://addons.mozilla.org/firefox/downloads/latest/lastpass-password-manager/latest.xpi";
            installation_mode = "force_installed";
          };
        };
        "ExtensionUpdate" = true;
        "FirefoxHome" = {
          "Search" = true;
          "TopSites" = false;
          "SponsoredTopSites" = false;
          "Highlights" = false;
          "Pocket" = false;
          "SponsoredPocket" = false;
          "Snippets" = false;
          "Locked" = true;
        };
        "FirefoxSuggest" = {
          "WebSuggestions" = false;
          "SponsoredSuggestions" = false;
          "ImproveSuggest" = false;
          "Locked" = true;
        };
        "FlashPlugin" = {
          "Default" = false;
        };
        "HardwareAcceleration" = true;
        "Homepage" = {
          "Locked" = false;
          "StartPage" = "none";
        };
        "NetworkPrediction" = false;
        "NewTabPage" = true;
        "NoDefaultBookmarks" = true;
        "OfferToSaveLogins" = false;
        "OverrideFirstRunPage" = "";
        "OverridePostUpdatePage" = "";
        "PasswordManagerEnabled" = false;
        "PopupBlocking" = {
          "Default" = true;
        };
        "PromptForDownloadLocation" = true;
        "SearchBar" = "unified";
        "SearchSuggestEnabled" = true;
        "ShowHomeButton" = false;
        "StartDownloadsInTempDirectory" = true;
        "UserMessaging" = {
          "WhatsNew" = false;
          "ExtensionRecommendations" = true;
          "FeatureRecommendations" = false;
          "UrlbarInterventions" = false;
          "SkipOnboarding" = true;
          "MoreFromMozilla" = false;
          "Locked" = false;
        };
        "UseSystemPrintDialog" = true;
      };
    };
  };
}
