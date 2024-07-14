{ pkgs, ... }:
let
  switch-all = pkgs.writeShellApplication {
    name = "switch-all";
    runtimeInputs = with pkgs; [ coreutils-full ];
    text = builtins.readFile ./switch-all.sh;
  };
in
{
  environment.systemPackages = with pkgs; [ switch-all ];
}
