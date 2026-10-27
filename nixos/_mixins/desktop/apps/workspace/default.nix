{
  lib,
  noughtyLib,
  pkgs,
  ...
}:
let
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
in
lib.mkIf (noughtyLib.hostHasTag "cg") {
  environment.systemPackages = [
    pkgs._1password-gui
  ];

  programs.chromium = {
    enable = true;
    extraOpts = workspaceBrowserOpts;
    extensions = workspaceBrowserExtensions;
  };
}
