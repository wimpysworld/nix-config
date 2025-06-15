{ pkgs, ... }:
{
  imports = [
    ./docker
  ];

  environment.systemPackages = with pkgs; [ ];
}
