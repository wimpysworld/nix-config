{ pkgs, ... }:
let
  name = builtins.baseNameOf (builtins.toString ./.);
  shellApplication = pkgs.writeShellApplication {
    inherit name;
    runtimeInputs = with pkgs; [
      nix-output-monitor
      uutils-coreutils-noprefix
    ];
    text = ''
      export NIXPKGS_ALLOW_UNFREE=1
      ${builtins.readFile ./${name}.sh}
    '';
  };
in
{
  home.packages = [
    shellApplication
  ];
}
