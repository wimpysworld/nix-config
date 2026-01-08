{
  pkgs,
  username,
  ...
}:
let
  installFor = [
    "martin"
  ];
in
{
  environment.systemPackages =
    with pkgs;
    [
      grandperspective
      keka
      maestral # CLI
    ]
    ++ lib.optionals (builtins.elem username installFor) [
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
    ++ lib.optionals (builtins.elem username installFor) [
      "beyond-compare"
      "docker-desktop"
      "heynote"
      "keybase"
      "mullvad-browser"
      "obs"
      "orion"
      "syncthing-app"
      "tailscale-app"
    ];
  };
}
