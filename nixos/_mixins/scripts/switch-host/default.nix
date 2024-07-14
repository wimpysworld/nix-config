{ pkgs, ... }:
let
  switch-host = pkgs.writeShellApplication {
    name = "switch-host";
    runtimeInputs = with pkgs; [
      bc
      coreutils-full
      nh
    ];
    text = builtins.readFile ./switch-host.sh;
  };
in
{
  environment.systemPackages = with pkgs; [ switch-host ];
}
