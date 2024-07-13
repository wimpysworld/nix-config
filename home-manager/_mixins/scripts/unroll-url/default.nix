{ pkgs, ... }:
let
  unroll-url = pkgs.writeShellApplication {
    name = "unroll-url";
    runtimeInputs = with pkgs; [
      coreutils-full
      curlMinimal
    ];
    text = builtins.readFile ./unroll-url.sh;
  };
in
{
  home.packages = with pkgs; [ unroll-url ];
}
