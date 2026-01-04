{
  config,
  inputs,
  lib,
  pkgs,
  username,
  ...
}:
let
  inherit (pkgs.stdenv) isLinux isDarwin;
  installFor = [ "martin" ];
  opencodePackage =
    if isLinux then
      inputs.nix-ai-tools.packages.${pkgs.stdenv.hostPlatform.system}.opencode
    else if isDarwin then
      pkgs.unstable.opencode
    else
      pkgs.opencode;
in
lib.mkIf (lib.elem username installFor) {
  home.file."${config.xdg.configHome}/zed/keymap.json" = lib.mkIf config.programs.zed-editor.enable {
    text = builtins.toJSON [
      {
        bindings = {
          "cmd-alt-o" = [
            "agent::NewExternalAgentThread"
            {
              agent = {
                custom = {
                  name = "OpenCode";
                  command = {
                    command = "opencode";
                    args = [ "acp" ];
                  };
                };
              };
            }
          ];
        };
      }
    ];
  };

  programs = {
    opencode = {
      enable = true;
      package = opencodePackage;
    };
    vscode = lib.mkIf config.programs.vscode.enable {
      profiles.default = {
        extensions = with pkgs; [
          vscode-marketplace.sst-dev.opencode
        ];
      };
    };
    zed-editor = lib.mkIf config.programs.zed-editor.enable {
      extensions = [
        "opencode"
      ];
    };
  };
}
