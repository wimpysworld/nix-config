{ config, pkgs, ... }:
let
  name = builtins.baseNameOf (builtins.toString ./.);
  shellApplication = pkgs.writeShellApplication {
    inherit name;
    runtimeInputs = with pkgs; [
      bc
      coreutils-full
      gawk
      gnused
      lima-bin
      procps
    ];
    text = builtins.readFile ./${name}.sh;
  };
in
{
  home = {
    file = {
      "${config.home.homeDirectory}/.lima/_templates/ubuntu-24.yml".text = builtins.readFile ./ubuntu-24.yml;
      "${config.home.homeDirectory}/.lima/_templates/ubuntu-22.yml".text = builtins.readFile ./ubuntu-22.yml;
    };
    packages = with pkgs; [ shellApplication ];
  };
  programs.fish.shellAliases = {
    create-grozbok = "lima-create grozbok";
    create-zeta = "lima-create zeta";
    grozbok = "limactl shell grozbok";
    zeta = "limactl shell zeta";
  };

}
