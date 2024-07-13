{ pkgs, ... }:
let
  purge-gpu-caches = pkgs.writeShellApplication {
    name = "purge-gpu-caches";
    runtimeInputs = with pkgs; [
      coreutils-full
      fd
    ];
    text = builtins.readFile ./purge-gpu-caches.sh;
  };
in
{
  home.packages = with pkgs; [ purge-gpu-caches ];
}
