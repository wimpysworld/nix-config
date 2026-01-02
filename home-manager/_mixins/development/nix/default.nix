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
      nixd
      nix-diff
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
          "nix.formatterPath" = "nixfmt";
          "nix.serverPath" = "${pkgs.nixd}/bin/nixd";
          "nix.serverSettings" = {
            "nixd" = {
              "formatting" = {
                "command" = [ "${pkgs.nixfmt-rfc-style}/bin/nixfmt" ];
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
                "command" = "${pkgs.nixfmt-rfc-style}/bin/nixfmt";
                "arguments" = [
                  "--quiet"
                  "--"
                ];
              };
            };
            "language_servers" = [
              "${pkgs.nixd}/bin/nixd"
            ];
          };
        };
        "lsp" = {
          "nixd" = {
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
