{
  catppuccinPalette,
  config,
  lib,
  noughtyLib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;
  isWorkHost = noughtyLib.hostHasTag "cg";

  mullvadPolicies = pkgs.writeText "mullvad-browser-policies.json" (
    builtins.toJSON {
      policies = {
        SearchEngines = {
          Default = "Brave Search";
          DefaultPrivate = "Brave Search";
        };
      };
    }
  );

  mullvadBrowser =
    (pkgs.mullvad-browser.override {
      extraPrefs = ''
        // General -> Content alignment: top
        pref("privacy.resistFingerprinting.letterboxing.vcenter", false);

        // Address Bar -> disable all suggestions
        pref("browser.urlbar.suggest.history", false);
        pref("browser.urlbar.suggest.bookmark", false);
        pref("browser.urlbar.suggest.openpage", false);
        pref("browser.urlbar.suggest.topsites", false);
        pref("browser.urlbar.suggest.engines", false);
        pref("browser.urlbar.suggest.quickactions", false);
        pref("browser.urlbar.quickactions.enabled", false);
        pref("browser.urlbar.shortcuts.actions", false);

        // Privacy & Security -> History
        pref("privacy.history.custom", true);
        pref("browser.privatebrowsing.autostart", false);
        pref("permissions.memory_only", false);
        pref("places.history.enabled", true);
        pref("browser.formfill.enable", false);
        pref("privacy.sanitize.sanitizeOnShutdown", true);

        // Clear history when Mullvad Browser closes (v2 and legacy v1 branches)
        pref("privacy.sanitize.clearOnShutdown.hasMigratedToNewPrefs3", true);
        pref("privacy.clearOnShutdown_v2.browsingHistoryAndDownloads", true);
        pref("privacy.clearOnShutdown_v2.cookiesAndStorage", false);
        pref("privacy.clearOnShutdown_v2.cache", true);
        pref("privacy.clearOnShutdown_v2.formdata", true);
        pref("privacy.clearOnShutdown_v2.siteSettings", false);
        pref("privacy.clearOnShutdown.history", true);
        pref("privacy.clearOnShutdown.downloads", true);
        pref("privacy.clearOnShutdown.cookies", false);
        pref("privacy.clearOnShutdown.sessions", false);
        pref("privacy.clearOnShutdown.offlineApps", false);
        pref("privacy.clearOnShutdown.cache", true);
        pref("privacy.clearOnShutdown.formdata", true);
        pref("privacy.clearOnShutdown.siteSettings", false);
      '';
    }).overrideAttrs
      (old: {
        postInstall = (old.postInstall or "") + ''
          install -Dvm644 ${mullvadPolicies} $out/share/mullvad-browser/distribution/policies.json
        '';
        preFixup = (old.preFixup or "") + ''
          gappsWrapperArgs+=(
            --set MOZ_LEGACY_PROFILES 1
            --set MOZ_ALLOW_DOWNGRADE 1
          )
        '';
      });
in
lib.mkIf (host.is.linux && host.is.workstation && !isWorkHost && noughtyLib.isUser [ "martin" ]) {
  home.packages = [
    mullvadBrowser
  ];

  programs = {
    firefox = {
      policies = {
        # Check about:support for extension/add-on ID strings.
        ExtensionSettings = {
          "uBlock0@raymondhill.net" = {
            install_url = "https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi";
            installation_mode = "force_installed";
          };
          "harper@writewithharper.com" = {
            install_url = "https://addons.mozilla.org/firefox/downloads/latest/private-grammar-checker-harper/latest.xpi";
            installation_mode = "force_installed";
          };
          "gdpr@cavi.au.dk" = {
            install_url = "https://addons.mozilla.org/firefox/downloads/latest/consent-o-matic/latest.xpi";
            installation_mode = "force_installed";
          };
          "sponsorBlocker@ajay.app" = {
            install_url = "https://addons.mozilla.org/firefox/downloads/latest/sponsorblock/latest.xpi";
            installation_mode = "force_installed";
          };
          "{762f9885-5a13-4abd-9c77-433dcd38b8fd}" = {
            install_url = "https://addons.mozilla.org/firefox/downloads/latest/return-youtube-dislikes/latest.xpi";
            installation_mode = "force_installed";
          };
          "easyscreenshot@mozillaonline.com" = {
            install_url = "https://addons.mozilla.org/firefox/downloads/latest/easyscreenshot/latest.xpi";
            installation_mode = "force_installed";
          };
          "search@kagi.com" = {
            install_url = "https://addons.mozilla.org/firefox/downloads/latest/kagi-search-for-firefox/latest.xpi";
            installation_mode = "force_installed";
          };
          "newtaboverride@agenedia.com" = {
            install_url = "https://addons.mozilla.org/firefox/downloads/latest/new-tab-override/latest.xpi";
            installation_mode = "force_installed";
          };
          "enterprise-policy-generator@agenedia.com" = {
            install_url = "https://addons.mozilla.org/firefox/downloads/latest/enterprise-policy-generator/latest.xpi";
            installation_mode = "force_installed";
          };
          "{2adf0361-e6d8-4b74-b3bc-3f450e8ebb69}" = {
            install_url = "https://addons.mozilla.org/firefox/downloads/latest/catppuccin-${catppuccinPalette.flavor}-${catppuccinPalette.accent}-git/latest.xpi";
            installation_mode = "force_installed";
          };
          "{bbb880ce-43c9-47ae-b746-c3e0096c5b76}" = {
            install_url = "https://addons.mozilla.org/firefox/downloads/latest/catppuccin-web-file-icons/latest.xpi";
            installation_mode = "force_installed";
          };
          "{7a7a4a92-a2a0-41d1-9fd7-1e92480d612d}" = {
            install_url = "https://addons.mozilla.org/firefox/downloads/latest/styl-us/latest.xpi";
            installation_mode = "force_installed";
          };
        };
        "Homepage" = {
          "URL" = "https://kagi.com";
        };
        "PromptForDownloadLocation" = true;
        "SearchEngines" = {
          "Add" = [
            {
              "Description" = "Kagi";
              "IconURL" = "https://assets.kagi.com/v2/apple-touch-icon.png";
              "Method" = "GET";
              "Name" = "Kagi";
              "SuggestURLTemplate" = "https://kagi.com/api/autosuggest?q={searchTerms}";
              "URLTemplate" = "https://kagi.com/search?q={searchTerms}";
            }
          ];
          "Default" = "Kagi";
          "DefaultPrivate" = "Kagi";
          "Remove" = [
            "Bing"
            "eBay"
            "Google"
          ];
        };
      };
    };
  };
}
