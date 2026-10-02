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
    [
      maestral # CLI
    ]
    ++ lib.optionals (noughtyLib.isUser [ "martin" ]) [
      brave
      stats
    ];

  homebrew = {
    casks = [
      "blender"
      "inkscape"
      "maestral" # GUI
      "zed"
    ]
    ++ lib.optionals config.noughty.host.is.workstation [ "ghostty" ]
    ++ lib.optionals (noughtyLib.isUser [ "martin" ]) [
      "beyond-compare"
      "orion"
    ];
  };
}
