{
  catppuccinPalette,
  config,
  inputs,
  lib,
  noughtyLib,
  ...
}:
let
  inherit (config.noughty) host;
  mkExtension = pluginId: {
    install_url = "https://addons.mozilla.org/firefox/downloads/latest/${pluginId}/latest.xpi";
    installation_mode = "force_installed";
  };
in
{
  imports = [
    inputs.zen-browser.homeModules.beta
  ];

  config =
    lib.mkIf (host.is.linux && noughtyLib.isUser [ "martin" ] && noughtyLib.hostHasTag "workspace")
      {
        programs.zen-browser = {
          enable = true;

          policies = {
            AutofillAddressEnabled = false;
            AutofillCreditCardEnabled = false;
            CaptivePortal = true;
            Cookies = {
              AcceptThirdParty = "from-visited";
              Behavior = "reject-tracker";
              BehaviorPrivateBrowsing = "reject-tracker";
              RejectTracker = true;
            };
            DisableAppUpdate = true;
            DisableDefaultBrowserAgent = true;
            DisableFeedbackCommands = true;
            DisableFirefoxStudies = true;
            DisableFormHistory = true;
            DisablePocket = true;
            DisableProfileImport = true;
            DisableSetDesktopBackground = true;
            DisableTelemetry = true;
            DisplayBookmarksToolbar = "never";
            DisplayMenuBar = "default-off";
            DNSOverHTTPS = {
              Enabled = false;
            };
            DontCheckDefaultBrowser = true;
            EnableTrackingProtection = {
              Value = false;
              Locked = false;
              Cryptomining = true;
              EmailTracking = true;
              Fingerprinting = true;
            };
            EncryptedMediaExtensions = {
              Enabled = true;
              Locked = true;
            };
            ExtensionUpdate = true;
            # Check about:support for extension/add-on ID strings.
            ExtensionSettings = {
              "support@lastpass.com" = mkExtension "lastpass-password-manager";
              "uBlock0@raymondhill.net" = mkExtension "ublock-origin";
              "87677a2c52b84ad3a151a4a72f5bd3c4@jetpack" = mkExtension "grammarly-1";
              "gdpr@cavi.au.dk" = mkExtension "consent-o-matic";
              "sponsorBlocker@ajay.app" = mkExtension "sponsorblock";
              "{762f9885-5a13-4abd-9c77-433dcd38b8fd}" = mkExtension "return-youtube-dislikes";
              "easyscreenshot@mozillaonline.com" = mkExtension "easyscreenshot";
              "search@kagi.com" = mkExtension "kagi-search-for-firefox";
              "newtaboverride@agenedia.com" = mkExtension "new-tab-override";
              "enterprise-policy-generator@agenedia.com" = mkExtension "enterprise-policy-generator";
              "{2adf0361-e6d8-4b74-b3bc-3f450e8ebb69}" = {
                install_url = "https://addons.mozilla.org/firefox/downloads/latest/catppuccin-${catppuccinPalette.flavor}-${catppuccinPalette.accent}-git/latest.xpi";
                installation_mode = "force_installed";
              };
              "{bbb880ce-43c9-47ae-b746-c3e0096c5b76}" = mkExtension "catppuccin-web-file-icons";
              "{7a7a4a92-a2a0-41d1-9fd7-1e92480d612d}" = mkExtension "styl-us";
              # Workspace-specific extensions.
              # Note: Ramp and Meet Linky are Chrome-only; no AMO listing exists.
              "{d634138d-c276-4fc8-924b-40a0ea21d284}" = mkExtension "1password-x-password-manager"; # 1Password
              "teamgolinks@gmail.com" = mkExtension "golinks"; # GoLinks
              "plugin@okta.com" = mkExtension "okta-browser-plugin"; # Okta
              "{315f61e5-f0ce-4d6e-a521-70e8da512405}" = mkExtension "glean"; # Glean
            };
            FirefoxHome = {
              Search = true;
              TopSites = false;
              SponsoredTopSites = false;
              Highlights = false;
              Pocket = false;
              SponsoredPocket = false;
              Snippets = false;
              Locked = true;
            };
            FirefoxSuggest = {
              WebSuggestions = false;
              SponsoredSuggestions = false;
              ImproveSuggest = false;
              Locked = true;
            };
            FlashPlugin = {
              Default = false;
            };
            HardwareAcceleration = true;
            Homepage = {
              URL = "https://kagi.com";
              Locked = false;
              StartPage = "none";
            };
            NetworkPrediction = false;
            NewTabPage = true;
            NoDefaultBookmarks = true;
            OfferToSaveLogins = false;
            OverrideFirstRunPage = "";
            OverridePostUpdatePage = "";
            PasswordManagerEnabled = false;
            PopupBlocking = {
              Default = true;
            };
            PromptForDownloadLocation = true;
            SearchBar = "unified";
            SearchEngines = {
              Add = [
                {
                  Description = "Kagi";
                  IconURL = "https://assets.kagi.com/v2/apple-touch-icon.png";
                  Method = "GET";
                  Name = "Kagi";
                  SuggestURLTemplate = "https://kagi.com/api/autosuggest?q={searchTerms}";
                  URLTemplate = "https://kagi.com/search?q={searchTerms}";
                }
              ];
              Default = "Kagi";
              DefaultPrivate = "Kagi";
              Remove = [
                "Bing"
                "eBay"
                "Google"
              ];
            };
            SearchSuggestEnabled = true;
            ShowHomeButton = false;
            StartDownloadsInTempDirectory = true;
            UserMessaging = {
              WhatsNew = false;
              ExtensionRecommendations = true;
              FeatureRecommendations = false;
              UrlbarInterventions = false;
              SkipOnboarding = true;
              MoreFromMozilla = false;
              Locked = false;
            };
            UseSystemPrintDialog = true;
          };
        };
      };
}
