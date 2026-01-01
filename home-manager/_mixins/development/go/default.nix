{
  config,
  lib,
  pkgs,
  username,
  ...
}:
let
  installFor = [ "martin" ];
in
lib.mkIf (lib.elem username installFor) {
  home = {
    packages = with pkgs; [
      delve
      go
      gopls
    ];
    sessionPath = [
      "${config.home.homeDirectory}/.local/go/bin"
    ];
    sessionVariables = {
      GOPATH = "${config.home.homeDirectory}/.local/go";
      GOCACHE = "${config.home.homeDirectory}/.local/go/cache";
    };
  };

  programs = {
    vscode = lib.mkIf config.programs.vscode.enable {
      profiles.default = {
        userSettings = {
          "gopls.ui.semanticTokens" = true;
        };
        extensions = with pkgs; [
          vscode-marketplace.golang.go
        ];
      };
    };
  };
}
