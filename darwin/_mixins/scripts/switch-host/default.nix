{ pkgs, ... }:
let
  name = builtins.baseNameOf (builtins.toString ./.);
  shellApplication = pkgs.writeShellApplication {
    inherit name;
    runtimeInputs = with pkgs; [
      bc
      uutils-coreutils-noprefix
    ];
    text = builtins.readFile ./${name}.sh;
  };
in
{
  environment.systemPackages = with pkgs; [ shellApplication ];
}
