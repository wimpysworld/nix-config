{
  config,
  inputs,
  lib,
  pkgs,
  username,
  ...
}:
let
  installFor = [ "martin" ];

  # Domains to auto-approve for URL access in Copilot chat
  approvedDomains = [
    "anthrophic.com"
    "docs.anthropic.com"
    "claude.com"
    "code.claude.com"
    "platform.claude.com"
    "github.com"
    "docs.github.com"
    "raw.githubusercontent.com"
    "opencode.ai"
    "zed.dev"
  ];

  # Generate autoApprove configuration from domain list
  mkAutoApprove =
    domains:
    lib.genAttrs (map (domain: "https://${domain}") domains) (_: {
      approveRequest = true;
      approveResponse = true;
    });
in
lib.mkIf (lib.elem username installFor) {
  home = {
    packages = [
      inputs.nix-ai-tools.packages.${pkgs.stdenv.hostPlatform.system}.copilot-cli
      inputs.nix-ai-tools.packages.${pkgs.stdenv.hostPlatform.system}.spec-kit
    ];
  };
  programs = {
    vscode = lib.mkIf config.programs.vscode.enable {
      profiles.default = {
        userSettings = {
          "chat.checkpoints.showFileChanges" = true;
          "chat.edits2.enabled" = true;
          "chat.editor.fontFamily" = "FiraCode Nerd Font Mono";
          "chat.editor.fontSize" = 16;
          "chat.fontFamily" = "Work Sans";
          "chat.fontSize" = 16;
          "chat.tools.terminal.blockDetectedFileWrites" = "never";
          "chat.tools.urls.autoApprove" = mkAutoApprove approvedDomains;
          "github.copilot.chat.anthropic.thinking.enabled" = true;
          "github.copilot.chat.codesearch.enabled" = true;
          "inlineChat.enableV2" = true;
        };
        extensions = with pkgs; [
          vscode-marketplace.github.copilot-chat
        ];
      };
    };
    zed-editor = lib.mkIf config.programs.zed-editor.enable {
      userSettings = {
        agent = {
          commit_message_model = {
            provider = "copilot_chat";
            model = "claude-haiku-4.5";
          };
          default_model = {
            provider = "copilot_chat";
            model = "claude-sonnet-4.5";
          };
          inline_assistant_model = {
            provider = "copilot_chat";
            model = "claude-haiku-4.5";
          };
          thread_summary_model = {
            provider = "copilot_chat";
            model = "gpt-5-mini";
          };
          features = {
            edit_prediction_provider = "copilot";
          };
        };
      };
    };
  };
}
