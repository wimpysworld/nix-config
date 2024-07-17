{ pkgs, ... }:
let
  template = pkgs.writeShellApplication {
    name = "template";
    runtimeInputs = with pkgs; [
      coreutils-full
    ];
    text = builtins.readFile ./template.sh;
  };
in
{
  home.packages = with pkgs; [ template ];
}
