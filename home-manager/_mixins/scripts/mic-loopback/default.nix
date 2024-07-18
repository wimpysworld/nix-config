{ pkgs, ... }:
let
  mic-loopback = pkgs.writeShellApplication {
    name = "mic-loopback";
    runtimeInputs = with pkgs; [
      coreutils-full
      gnugrep
      gnused
      pipewire
      procps
      pulsemixer
    ];
    text = builtins.readFile ./mic-loopback.sh;
  };
in
{
  home.packages = with pkgs; [ mic-loopback ];
}
