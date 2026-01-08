{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    brave
    grandperspective
    keka
    maestral # CLI
    stats
    utm
  ];

  homebrew = {
    casks = [
      "beyond-compare"
      "docker-desktop"
      "heynote"
      "keybase"
      "maestral" # GUI
      "mullvad-browser"
      "obs"
      "orion"
      "syncthing-app"
      "tailscale-app"
    ];
  };
}
