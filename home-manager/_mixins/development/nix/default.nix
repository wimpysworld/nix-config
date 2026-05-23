{
  config,
  lib,
  pkgs,
  ...
}:
{
  home = {
    packages = with pkgs; [
      deadnix
      nil
      nixd
      nix-diff
      nixfmt
      nixfmt-tree
      statix
    ];
  };

  claude-code.lspServers.nix = {
    command = lib.getExe pkgs.nixd;
    extensionToLanguage = {
      ".nix" = "nix";
    };
  };

  fresh.settings.lsp.nix = {
    command = lib.getExe pkgs.nil;
    enabled = true;
    auto_start = true;
  };

  programs = {
    zed-editor = lib.mkIf config.programs.zed-editor.enable {
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
