{ pkgs }:
pkgs.writeShellApplication {
  name = "regreet-output-setup";
  runtimeInputs = with pkgs; [
    coreutils
    jq
    wlr-randr
  ];
  text = builtins.readFile ./regreet-output-setup.sh;
}
