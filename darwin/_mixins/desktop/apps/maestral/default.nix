{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [ maestral ];

  homebrew = {
    casks = [ "maestral" ];
  };
}
