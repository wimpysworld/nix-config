{ pkgs, ... }:
let
  build-all = pkgs.writeShellApplication {
    name = "build-all";
    runtimeInputs = with pkgs; [ coreutils-full ];
    text = builtins.readFile ./build-all.sh;
  };
in
{
  environment.systemPackages = with pkgs; [ build-all ];
}
