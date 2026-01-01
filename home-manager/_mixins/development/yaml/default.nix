{
  config,
  isWorkstation,
  lib,
  pkgs,
  username,
  ...
}:
let
  installFor = [ "martin" ];
in
lib.mkIf (lib.elem username installFor && isWorkstation) {
  home = {
    packages = with pkgs; [
      yaml-language-server
      yq-go # Terminal `jq` for YAML
    ];
  };

  programs = {
    vscode = lib.mkIf config.programs.vscode.enable {
      profiles.default = {
        userSettings = {
          "redhat.telemetry.enabled" = false;
        };
        extensions = with pkgs; [
          vscode-marketplace.redhat.vscode-yaml
        ];
      };
    };
  };
}
