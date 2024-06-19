{ desktop, hostname, lib, pkgs, username, ... }:
{
  programs = {
    # - https://mozilla.github.io/policy-templates/
    firefox = {
      policies = {
        # Check about:support for extension/add-on ID strings.
        ExtensionSettings = {
          "uBlock0@raymondhill.net" = {
            install_url = "https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi";
            installation_mode = "force_installed";
          };
          "87677a2c52b84ad3a151a4a72f5bd3c4@jetpack" = {
            install_url = "https://addons.mozilla.org/firefox/downloads/latest/grammarly-1/latest.xpi";
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
            install_url = "https://addons.mozilla.org/firefox/downloads/latest/catppuccin-mocha-blue-git/latest.xpi";
            installation_mode = "force_installed";
          };
        };
        "Homepage" = {
          "URL" = "https://${hostname}.drongo-gamma.ts.net";
        };
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
