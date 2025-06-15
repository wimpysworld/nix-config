{
  lib,
  pkgs,
  username,
  ...
}:
let
  installFor = [ "none" ];
in
lib.mkIf (lib.elem "${username}" installFor) {
  environment = {
    shellAliases = {
      docker = "${pkgs.podman}/bin/podman";
    };
    systemPackages = with pkgs; [
      act
      podman
    ];
  };

  homebrew = {
    casks = [ "podman-desktop" ];
  };

  programs.fish.shellAliases = {
    docker = "${pkgs.podman}/bin/podman";
  };
}
