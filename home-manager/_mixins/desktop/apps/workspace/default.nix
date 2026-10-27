{
  config,
  inputs,
  lib,
  noughtyLib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;

  # Wrap Slack to open all URLs in Chrome
  slackChrome = inputs.xdg-override.lib.wrapPackage {
    nameMatch = [
      {
        case = "^https?://";
        command = "google-chrome-stable";
      }
    ];
  } pkgs.slack;

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
lib.mkIf (host.is.linux && noughtyLib.hostHasTag "cg") {
  programs.google-chrome = {
    enable = true;
    commandLineArgs = [
      "--enable-features=AcceleratedVideoDecodeLinuxGL,AcceleratedVideoDecodeLinuxZeroCopyGL,AcceleratedVideoEncoder,VaapiIgnoreDriverChecks"
    ];
  };

  home.packages = [
    slackChrome
    chromeXdgOpen
  ];
}
