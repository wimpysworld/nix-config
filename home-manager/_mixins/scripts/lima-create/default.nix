{ pkgs, ... }:
let
  lima-create = pkgs.writeShellApplication {
    name = "lima-create";
    runtimeInputs = with pkgs; [
      bc
      coreutils-full
      gawk
      gnused
      lima-bin
      procps
    ];
    text = builtins.readFile ./lima-create.sh;
  };
in
{
  home.packages = with pkgs; [ lima-create ];
  programs.fish.shellAliases = {
    lima-create-builder = "lima-create builder";
    lima-create-default = "lima-create default";
  };
}
