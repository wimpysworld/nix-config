{ pkgs, ... }:
let
  nixfmt-plus = pkgs.writeShellApplication {
    name = "nixfmt-plus";
    runtimeInputs = with pkgs; [
      deadnix
      nixfmt-rfc-style
      statix
    ];
    text = builtins.readFile ./nixfmt-plus.sh;
  };
in
{
  home = {
    packages = with pkgs; [ nixfmt-plus ];
  };
}
