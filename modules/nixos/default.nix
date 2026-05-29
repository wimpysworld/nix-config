# Reusable NixOS modules
# - https://wiki.nixos.org/wiki/NixOS_modules
{
  falcon-sensor = import ./falcon-sensor.nix;
  wavebox = import ./wavebox.nix;
}
