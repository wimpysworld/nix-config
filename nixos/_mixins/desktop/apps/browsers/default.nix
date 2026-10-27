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
    environment.etc = {
      "brave/policies/managed/brave.json".text = builtins.toJSON {
        BraveAIChatEnabled = false;
        BraveDeAmpEnabled = true;
        BraveDebouncingEnabled = true;
        BraveGlobalPrivacyControlEnabled = true;
        BraveLocalAIEnabled = false;
        BraveNewsDisabled = true;
        BraveP3AEnabled = false;
        BravePlaylistEnabled = false;
        BraveReduceLanguageEnabled = true;
        BraveRewardsDisabled = true;
        BraveSpeedreaderEnabled = false;
        BraveStatsPingEnabled = false;
        BraveTalkDisabled = true;
        BraveTrackingQueryParametersFilteringEnabled = true;
        BraveVPNDisabled = true;
        BraveWalletDisabled = true;
        BraveWaybackMachineEnabled = false;
        BraveWebDiscoveryEnabled = false;
        TorDisabled = true;
      };
      # - https://learn.microsoft.com/en-us/deployedge/microsoft-edge-policies
      "opt/edge/policies/managed/policies.json".text = builtins.toJSON {
        ExtensionInstallForcelist = map (
          id: "${id};https://clients2.google.com/service/update2/crx"
        ) config.programs.chromium.extensions;
        # Copilot, Sidebar, and Generative AI
        AIGenThemesEnabled = false;
        ComposeInlineEnabled = false;
        CopilotPageContext = false;
        EdgeEntraCopilotPageContext = false;
        EdgeHistoryAISearchEnabled = false;
        GenAILocalFoundationalModelSettings = 1;
        HubsSidebarEnabled = false;
        Microsoft365CopilotChatIconEnabled = false;
        SearchInSidebarEnabled = 2;
        # Shopping, Rewards, Workspaces, and Recommendations
        EdgeEDropEnabled = false;
        EdgeShoppingAssistantEnabled = false;
        EdgeWorkspacesEnabled = false;
        HideFirstRunExperience = true;
        ShowMicrosoftRewards = false;
        ShowRecommendationsEnabled = false;
        SpotlightExperiencesAndRecommendationsEnabled = false;
        # New Tab Page and Startup
        FavoritesBarEnabled = false;
        HomepageIsNewTabPage = true;
        NewTabPageAllowedBackgroundTypes = 3;
        NewTabPageContentEnabled = false;
        NewTabPageHideDefaultTopSites = true;
        NewTabPageQuickLinksEnabled = false;
        RestoreOnStartup = 1;
        ShowHomeButton = false;
        # Privacy and Telemetry
        AlternateErrorPagesEnabled = false;
        DiagnosticData = 0;
        Edge3PSerpTelemetryEnabled = false;
        ExperimentationAndConfigurationServiceControl = 0;
        NetworkPredictionOptions = 2;
        PersonalizationReportingEnabled = false;
        ResolveNavigationErrorsUseWebService = false;
        SiteSafetyServicesEnabled = false;
        TrackingPrevention = 3;
        UserFeedbackAllowed = false;
        # Passwords and Autofill
        AutofillAddressEnabled = false;
        AutofillCreditCardEnabled = false;
        EdgeAutofillMlEnabled = false;
        PasswordExportEnabled = false;
        PasswordGeneratorEnabled = false;
        PasswordManagerEnabled = false;
        PasswordMonitorAllowed = false;
        PaymentMethodQueryEnabled = false;
        # Network, Downloads, Printing, Content, and Spellcheck
        BackgroundModeEnabled = false;
        BuiltInDnsClientEnabled = false;
        DefaultGeolocationSetting = 3;
        DefaultImagesSetting = 1;
        DefaultPopupsSetting = 1;
        DefaultSearchProviderEnabled = true;
        PrintingPaperSizeDefault = {
          name = "iso_a4_210x297mm";
        };
        PromptForDownloadLocation = true;
        SpellcheckEnabled = true;
        SpellcheckLanguage = [
          "en-GB"
          "en-US"
        ];
      };
    };
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
          "DomainReliabilityAllowed" = false;
          "FeedbackSurveysEnabled" = false;
          "MetricsReportingEnabled" = false;
          "SpellCheckServiceEnabled" = false;
          # Misc; DNS
          "BuiltInDnsClientEnabled" = false;
          # Misc; Tabs
          "NTPCardsVisible" = false;
          "NTPCustomBackgroundEnabled" = false;
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
          "PromotionsEnabled" = false;
          "ShoppingListEnabled" = false;
          "ShowFullUrlsInAddressBar" = true;
          "SpellcheckEnabled" = true;
          "SpellcheckLanguage" = [
            "en-GB"
            "en-US"
          ];
          # Content settings
          "DefaultGeolocationSetting" = 3;
          "DefaultImagesSetting" = 1;
          "DefaultPopupsSetting" = 1;
          "DefaultSearchProviderEnabled" = true;
          # Generative AI; these settings disable the AI features to prevent data collection
          "AIModeSettings" = 1;
          "AutofillGenAiSettings" = 2;
          "AutofillPredictionSettings" = 2;
          "BuiltInAIAPIsEnabled" = false;
          "CreateThemesSettings" = 2;
          "DevToolsGenAiSettings" = 2;
          "GeminiActOnWebSettings" = 1;
          "GeminiSparkSettings" = 1;
          "GenAILocalFoundationalModelSettings" = 1;
          "HelpMeWriteSettings" = 2;
          "SearchContentSharingSettings" = 1;
          "TabCompareSettings" = 2;
          "ThirdPartyAiChatSettings" = 1;
          # Password manager
          "PasswordDismissCompromisedAlertEnabled" = true;
          "PasswordLeakDetectionEnabled" = false;
          "PasswordManagerEnabled" = false;
          "PasswordSharingEnabled" = false;
          # Printing
          "PrintingPaperSizeDefault" = {
            name = "iso_a4_210x297mm";
          };
          # Safe Browsing
          "SafeBrowsingProtectionLevel" = 1;
          "SafeBrowsingProxiedRealTimeChecksAllowed" = false;
          "SafeBrowsingSurveysEnabled" = false;
          # Startup, Home and New Tab Page
          "HomepageIsNewTabPage" = true;
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
