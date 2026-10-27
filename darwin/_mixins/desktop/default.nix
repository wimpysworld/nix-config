{
  config,
  lib,
  noughtyLib,
  pkgs,
  ...
}:
{
  environment.systemPackages =
    with pkgs;
    lib.optionals (noughtyLib.isUser [ "martin" ]) [
      stats
    ];

  homebrew = {
    masApps = lib.mkIf (noughtyLib.isUser [ "martin" ]) {
      "LastPass for Safari" = 6504626762;
      "uBlock Origin Lite" = 6745342698;
      "Consent-O-Matic" = 1606897889;
      "Kagi for Safari" = 1622835804;
      "Xcode" = 497799835;
    };
    casks = [
      "blender"
      "inkscape"
      "zed"
    ]
    ++ lib.optionals (!(noughtyLib.hostHasTag "cg")) [ "maestral" ]
    ++ lib.optionals config.noughty.host.is.workstation [ "ghostty" ]
    ++ lib.optionals (noughtyLib.isUser [ "martin" ]) [
      "beyond-compare"
    ];
  };
}
