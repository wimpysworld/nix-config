{ pkgs, ... }:
let
  build-host = pkgs.writeShellApplication {
    name = "build-host";
    runtimeInputs = with pkgs; [
      bc
      coreutils-full
      nh
    ];
    text = builtins.readFile ./build-host.sh;
  };
in
{
  environment.systemPackages = with pkgs; [ build-host ];
}
