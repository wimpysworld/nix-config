{ pkgs, ... }:
let
  build-iso = pkgs.writeShellApplication {
    name = "build-iso";
    runtimeInputs = with pkgs; [
      bc
      coreutils-full
      nix-output-monitor
    ];
    text = builtins.readFile ./build-iso.sh;
  };
in
{
  environment.systemPackages = with pkgs; [ build-iso ];
}
