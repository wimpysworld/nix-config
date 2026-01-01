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
      golangci-lint
      gopls
    ];
    sessionPath = [
      "${config.home.homeDirectory}/.local/go/bin"
    ];
    sessionVariables = {
      GOBIN = "${config.home.homeDirectory}/.local/go/bin";
      GOCACHE = "${config.home.homeDirectory}/.local/go/cache";
      GOPATH = "${config.home.homeDirectory}/.local/go";
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
    zed-editor = lib.mkIf config.programs.zed-editor.enable {
      extensions = [
        "golangci-lint"
        "gosum"
      ];
    };
  };
}
