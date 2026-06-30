{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;
in
lib.mkIf host.is.workstation {
  home = {
    packages = with pkgs; [
      delve
      go
      go-licenses
      golangci-lint
      golangci-lint-langserver
      gopls
      goreleaser
      gotools
      govulncheck
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

  claude-code.lspServers.go = {
    command = lib.getExe pkgs.gopls;
    extensionToLanguage = {
      ".go" = "go";
    };
  };

  fresh.settings.lsp.go = [
    {
      name = "gopls";
      command = lib.getExe pkgs.gopls;
      enabled = true;
      auto_start = true;
      root_markers = [
        "go.mod"
        "go.work"
        ".git"
      ];
    }
    {
      name = "golangci-lint-langserver";
      command = lib.getExe pkgs.golangci-lint-langserver;
      enabled = true;
      auto_start = true;
      only_features = [ "diagnostics" ];
      root_markers = [
        "go.mod"
        "go.work"
        ".git"
      ];
    }
  ];

  programs = {
    zed-editor = lib.mkIf config.programs.zed-editor.enable {
      extensions = [
        "golangci-lint"
        "gosum"
      ];
      userSettings = {
        languages = {
          Go = {
            formatter = {
              external = {
                command = "gofmt";
                arguments = [ ];
              };
            };
            language_servers = [
              "gopls"
              "golangci-lint-langserver"
            ];
          };
        };
        lsp = {
          gopls = { };
          golangci-lint-langserver = { };
        };
      };
    };
  };
}
