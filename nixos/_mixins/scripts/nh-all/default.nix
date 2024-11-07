{ pkgs, ... }:
let
  name = builtins.baseNameOf (builtins.toString ./.);
  shellApplication = pkgs.writeShellApplication {
    inherit name;
    runtimeInputs = with pkgs; [ coreutils-full ];
    text = builtins.readFile ./${name}.sh;
  };
  buildAll = pkgs.writeScriptBin "build-all" ''nh-all build'';
  switchAll = pkgs.writeScriptBin "switch-all" ''nh-all switch'';
in
{
  environment.systemPackages = with pkgs; [
    shellApplication
    buildAll
    switchAll
  ];
}
