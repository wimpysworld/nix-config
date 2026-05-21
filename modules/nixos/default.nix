# Reusable NixOS modules
# - https://wiki.nixos.org/wiki/NixOS_modules
{
  falcon-sensor = import ./falcon-sensor.nix;
  ferdium = import ./ferdium.nix;
  wavebox = import ./wavebox.nix;
}
