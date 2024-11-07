{ pkgs, ... }:
let
  name = builtins.baseNameOf (builtins.toString ./.);
  shellApplication = pkgs.writeShellApplication {
    inherit name;
    runtimeInputs = with pkgs; [
      bc
      coreutils-full
      nh
    ];
    text = builtins.readFile ./${name}.sh;
  };
  buildHome = pkgs.writeScriptBin "build-home" ''nh-home build'';
  switchHome = pkgs.writeScriptBin "switch-home" ''nh-home switch'';
in
{
  home.packages = with pkgs; [
    shellApplication
    buildHome
    switchHome
  ];
}
