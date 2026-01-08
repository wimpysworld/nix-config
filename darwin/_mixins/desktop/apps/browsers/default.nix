{
  pkgs,
  ...
}:
{
  environment.systemPackages = with pkgs; [
    brave
  ];
  homebrew = {
    casks = [
      "mullvad-browser"
      "orion"
    ];
  };
}
