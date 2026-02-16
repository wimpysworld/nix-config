{ pkgs, ... }:
let
  name = builtins.baseNameOf (builtins.toString ./.);
  shellApplication = pkgs.writeShellApplication {
    inherit name;
    runtimeInputs = with pkgs; [
      coreutils
      git
      gnugrep
      gnused
      nix-output-monitor
      util-linux
      which
    ];
    text = builtins.readFile ./${name}.sh;
  };
  shellAliases = {
    norm = "noughty channel";
    nook = "noughty path";
    nope = "noughty spawn";
    nosh = "noughty shell";
    nout = "noughty run";
  };
in
{
  home.packages = [ shellApplication ];
  programs = {
    bash = {
      inherit shellAliases;
    };
    fish = {
      inherit shellAliases;
    };
    zsh = {
      inherit shellAliases;
    };
  };
}
