{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;
in
{
  home = {
    packages =
      with pkgs;
      [
        deadnix
        nix-diff
        nixfmt
        nixfmt-tree
        statix
      ]
      ++ lib.optionals (!host.is.server) [
        nil
        nixd
      ];
  };

  claude-code.lspServers = lib.mkIf (!host.is.server && config.programs.claude-code.enable) {
    nix = {
      command = lib.getExe pkgs.nixd;
      extensionToLanguage = {
        ".nix" = "nix";
      };
    };
  };

  programs.fresh-editor.settings.lsp.nix = lib.mkIf (!host.is.server) {
    command = lib.getExe pkgs.nil;
    enabled = true;
    auto_start = true;
  };

  programs = {
    zed-editor = lib.mkIf (!host.is.server && config.programs.zed-editor.enable) {
      userSettings = {
        languages = {
          Nix = {
            formatter = {
              external = {
                command = "${pkgs.nixfmt}/bin/nixfmt";
                arguments = [
                  "--quiet"
                  "--"
                ];
              };
            };
            language_servers = [
              "nixd"
            ];
          };
        };
        lsp = {
          nixd = {
            settings = {
              diagnostics = {
                suppress = [ "sema-extra-with" ];
              };
            };
          };
        };
      };
      extensions = [
        "nix"
      ];
    };
  };
}
