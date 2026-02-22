{
  lib,
  noughtyLib,
  pkgs,
  ...
}:
{
  environment.systemPackages =
    with pkgs;
    [
      grandperspective
      keka
      maestral # CLI
    ]
    ++ lib.optionals (noughtyLib.isUser [ "martin" ]) [
      brave
      stats
      utm
    ];

  homebrew = {
    casks = [
      "blender"
      "inkscape"
      "maestral" # GUI
    ]
    ++ lib.optionals (noughtyLib.isUser [ "martin" ]) [
      "beyond-compare"
      "docker-desktop"
      "keybase"
      "mullvad-browser"
      "obs"
      "orion"
      "tailscale-app"
    ];
  };
}
