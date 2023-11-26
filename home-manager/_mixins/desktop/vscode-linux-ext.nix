{ lib, pkgs, ... }:
let
  inherit (pkgs.stdenv) isLinux;
in
lib.mkIf isLinux {
  programs = {
    vscode = {
      extensions = with pkgs; [
        vscode-extensions.ms-vscode.cpptools
        vscode-extensions.ms-vsliveshare.vsliveshare
        vscode-extensions.vadimcn.vscode-lldb
      ];
    };
  };
}
