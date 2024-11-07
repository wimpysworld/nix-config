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
  buildHost = pkgs.writeScriptBin "build-host" ''nh-host build'';
  switchHost = pkgs.writeScriptBin "switch-host" ''nh-host switch'';
in
{
  environment.systemPackages = with pkgs; [
    shellApplication
    buildHost
    switchHost
  ];
}
