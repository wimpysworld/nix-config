{
  inputs,
  lib,
  noughtyLib,
  pkgs,
  ...
}:
let
  # Wrap Slack to open all URLs in Chrome
  slackChrome = inputs.xdg-override.lib.wrapPackage {
    nameMatch = [
      {
        case = "^https?://";
        command = "google-chrome-stable";
      }
    ];
  } pkgs.slack;

  workspaceBrowserOpts = {
    "AutofillAddressEnabled" = false;
    "AutofillCreditCardEnabled" = false;
    "PasswordManagerEnabled" = false;
    "PromptForDownloadLocation" = true;
    "SpellcheckEnabled" = true;
    "SpellcheckLanguage" = [
      "en-GB"
      "en-US"
    ];
  };

  workspaceBrowserExtensions = [
    "hdokiejnpimakedhajhdlcegeplioahd" # LastPass
    "lodbfhdipoipcjmlebjbgmmgekckhpfb" # Harper
    "dfjdfadcciciboknnahlhgonamhfgmhp" # Disable Automatic Gain Control
    "mdpfkohgfpidohkakdbpmnngaocglmhl" # Disable Ctrl + Scroll Zoom
    "aeblfdkhhhdcdjpifhhbdiojplfjncoa" # 1Password
    "mdkgfdijbhbcbajcdlebbodoppgnmhab" # GoLinks
    "glnpjglilkicbckjpbgcfkogebgllemb" # Okta
    "cfpdompphcacgpjfbonkdokgjhgabpij" # Glean
    "idefohglmnkliiadgfofeokcpjobdeik" # Ramp
    "mfmabgokainekahncfnijjpcfhjendmb" # Meet Linky
    "incpcifganmpehaiplhjlfphaflbkdoj" # Sigstore Close Post-Auth
  ];

  # Global xdg-open proxy to route specific URLs to Chrome
  chromeXdgOpen = inputs.xdg-override.lib.proxyPkg {
    inherit pkgs;
    nameMatch = [
      {
        case = "^https?://accounts.google.com";
        command = "google-chrome-stable";
      }
      {
        case = "^https?://github.com/login/device";
        command = "google-chrome-stable";
      }
      {
        case = "^https?://auth.chainguard.dev/activate";
        command = "google-chrome-stable";
      }
      {
        case = "^https?://issuer.enforce.dev";
        command = "google-chrome-stable";
      }
      {
        case = "^https?://oauth2.sigstore.dev/auth";
        command = "google-chrome-stable";
      }
      {
        case = "^https?://auth.openai.com/oauth";
        command = "google-chrome-stable";
      }
    ];
  };
in
lib.mkIf (noughtyLib.hostHasTag "cg") {
  environment.systemPackages = [
    pkgs._1password-gui
    pkgs.google-chrome
    slackChrome
    chromeXdgOpen
  ];

  programs.chromium = {
    enable = true;
    extraOpts = workspaceBrowserOpts;
    extensions = workspaceBrowserExtensions;
  };
}
