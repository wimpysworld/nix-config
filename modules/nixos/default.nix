# Reusable NixOS modules
# - https://wiki.nixos.org/wiki/NixOS_modules
{
  brave = import ./brave.nix;
  falcon-sensor = import ./falcon-sensor.nix;
}
