{
  config,
  lib,
  noughtyLib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;
  isWorkHost = noughtyLib.hostHasTag "cg";
  forFamily = [
    "agatha"
    "louise"
  ];
  forMartin = [ "martin" ];

  familyPackages = with pkgs; [
    google-chrome
    microsoft-edge
  ];
  martinPackages = with pkgs; [
    mullvad-browser
  ];

  basicExtensions = [
    { id = "hdokiejnpimakedhajhdlcegeplioahd"; } # LastPass
  ];
  advancedExtensions = [
    { id = "cjpalhdlnbpafiamejdnhcphjbkeiagm"; } # uBlock Origin
    { id = "lodbfhdipoipcjmlebjbgmmgekckhpfb"; } # Harper
    { id = "mdjildafknihdffpkfmmpnpoiajfjnjd"; } # Consent-O-Matic
    { id = "mnjggcdmjocbbbhaepdhchncahnbgone"; } # SponsorBlock for YouTube
    { id = "gebbhagfogifgggkldgodflihgfeippi"; } # Return YouTube Dislike
    { id = "fdpohaocaechififmbbbbbknoalclacl"; } # GoFullPage
    { id = "dfjdfadcciciboknnahlhgonamhfgmhp"; } # Disable Automatic Gain Control
    { id = "cdglnehniifkbagbbombnjghhcihifij"; } # Kagi
    { id = "dpaefegpjhgeplnkomgbcmmlffkijbgp"; } # Kagi Summariser
    #{ id = "bkkmolkhemgaeaeggcmfbghljjjoofoh"; } # Catppuccin Mocha
    { id = "lnjaiaapbakfhlbjenjkhffcdpoompki"; } # Catppuccin Web file explorer icons
    { id = "clngdbkpkpeebahjckkjfobafhncgmne"; } # Stylus
    { id = "mdpfkohgfpidohkakdbpmnngaocglmhl"; } # Disable Ctrl + Scroll Zoom
  ];

  firefoxPreferences =
    builtins.mapAttrs
      (_: value: {
        Value = value;
        Status = "default";
      })
      {
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
in
{
  imports = [ ./martin.nix ];
  config = lib.mkIf (host.is.workstation && !isWorkHost) {
    home.packages =
      lib.optionals (host.is.linux && noughtyLib.isUser forFamily) familyPackages
      ++ lib.optionals (host.is.linux && noughtyLib.isUser forMartin) martinPackages;

    # Install browser extensions via Home Manager on macOS; Linux uses NixOS /etc/brave/policies/managed.
    programs = {
      brave = {
        enable = host.is.darwin || (host.is.linux && noughtyLib.isUser forMartin);
        extensions = lib.optionals host.is.darwin (
          if (noughtyLib.isUser forMartin) then basicExtensions ++ advancedExtensions else basicExtensions
        );
      };
      # - https://mozilla.github.io/policy-templates/
      firefox = lib.mkIf host.is.linux {
        enable = true;
        configPath = ".mozilla/firefox";
        languagePacks = [
          "en-GB"
          "en-US"
        ];
        package = pkgs.firefox;
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
          "Preferences" = firefoxPreferences // {
            "media.getusermedia.audio.processing.agc.enabled" = {
              "Value" = false;
              "Status" = "locked";
            };
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
  };
}
