{
  config,
  lib,
  noughtyLib,
  ...
}:
let
  workspaceBrowserOpts = {
    "AIModeSettings" = 1;
    "AutofillAddressEnabled" = false;
    "AutofillCreditCardEnabled" = false;
    "AutofillGenAiSettings" = 2;
    "AutofillPredictionSettings" = 2;
    "BuiltInAIAPIsEnabled" = false;
    "CreateThemesSettings" = 2;
    "DevToolsGenAiSettings" = 2;
    "GeminiActOnWebSettings" = 1;
    "GeminiSparkSettings" = 1;
    "GenAILocalFoundationalModelSettings" = 1;
    "HelpMeWriteSettings" = 2;
    "PasswordManagerEnabled" = false;
    "PrintingPaperSizeDefault" = {
      name = "iso_a4_210x297mm";
    };
    "PromotionsEnabled" = false;
    "PromptForDownloadLocation" = true;
    "SearchContentSharingSettings" = 1;
    "SpellcheckEnabled" = true;
    "SpellcheckLanguage" = [
      "en-GB"
      "en-US"
    ];
    "TabCompareSettings" = 2;
    "ThirdPartyAiChatSettings" = 1;
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
  programs._1password-gui = {
    enable = true;
    polkitPolicyOwners = [ config.noughty.user.name ];
  };

  programs.chromium = {
    enable = true;
    extraOpts = workspaceBrowserOpts;
    extensions = workspaceBrowserExtensions;
  };
}
