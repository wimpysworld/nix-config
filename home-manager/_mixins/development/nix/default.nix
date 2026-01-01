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
      mcp-nixos
      nil
      nixfmt-rfc-style
    ];
  };

  programs = {
    vscode = lib.mkIf config.programs.vscode.enable {
      profiles.default = {
        userSettings = {
          "[nix]"."editor.defaultFormatter" = "jnoortheen.nix-ide";
          "[nix]"."editor.formatOnSave" = true;
          "[nix]"."editor.tabSize" = 2;
          "nix.enableLanguageServer" = true;
          "nix.serverPath" = "nil";
          "nix.serverSettings" = {
            "nil" = {
              "formatting" = {
                "command" = [ "nixfmt" ];
              };
            };
          };
        };
        extensions = with pkgs; [
          vscode-marketplace.jeff-hykin.better-nix-syntax
          vscode-marketplace.jnoortheen.nix-ide
        ];
      };
    };
    zed-editor = lib.mkIf config.programs.zed-editor.enable {
      extensions = [
        "nix"
      ];
      userSettings = {
        "languages" = {
          "Nix" = {
            "formatter" = {
              "external" = {
                "command" = "nixfmt";
                "arguments" = [
                  "--quiet"
                  "--"
                ];
              };
            };
            "language_servers" = [
              "nil"
              "!nixd"
            ];
          };
        };
        "lsp" = {
          "nil" = {
            "settings" = {
              "diagnostics" = {
                "ignored" = [ "unused_binding" ];
              };
            };
          };
        };
      };
    };
  };
}
