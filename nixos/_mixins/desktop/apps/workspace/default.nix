{
  hostname,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  installOn = [
    "bane"
    "malgus"
    "phasma"
    "vader"
    "zannah"
  ];

  # Wrap Slack to open all URLs in Wavebox
  slackWavebox = inputs.xdg-override.lib.wrapPackage {
    nameMatch = [
      {
        case = "^https?://";
        command = "wavebox";
      }
    ];
  } pkgs.slack;

  # Global xdg-open proxy to route specific URLs to Wavebox
  waveboxXdgOpen = inputs.xdg-override.lib.proxyPkg {
    inherit pkgs;
    nameMatch = [
      {
        case = "^https?://accounts.google.com";
        command = "wavebox";
      }
      {
        case = "^https?://github.com/login/device";
        command = "wavebox";
      }
      {
        case = "^https?://auth.chainguard.dev/activate";
        command = "wavebox";
      }
      {
        case = "^https?://issuer.enforce.dev";
        command = "wavebox";
      }
    ];
  };
in
lib.mkIf (lib.elem hostname installOn) {
  environment.systemPackages = [
    pkgs._1password-gui
    pkgs.wavebox
    slackWavebox
    waveboxXdgOpen
  ];

  programs.wavebox = {
    enable = true;
    extensions = [
      "hdokiejnpimakedhajhdlcegeplioahd" # LastPass
      "kbfnbcaeplbcioakkpcpgfkobkghlhen" # Grammarly
      "mdpfkohgfpidohkakdbpmnngaocglmhl" # Disable Ctrl + Scroll Zoom
      "aeblfdkhhhdcdjpifhhbdiojplfjncoa" # 1Password
      "mdkgfdijbhbcbajcdlebbodoppgnmhab" # GoLinks
      "glnpjglilkicbckjpbgcfkogebgllemb" # Okta
      "cfpdompphcacgpjfbonkdokgjhgabpij" # Glean
      "idefohglmnkliiadgfofeokcpjobdeik" # Ramp
      "mfmabgokainekahncfnijjpcfhjendmb" # Meet Linky
    ];
  };
}
