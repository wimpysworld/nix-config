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
  vscodeUserDir =
    if isLinux then
      "${config.xdg.configHome}/Code/User"
    else if isDarwin then
      "/Users/${username}/Library/Application Support/Code/User"
    else
      throw "Unsupported platform";
in
lib.mkIf (lib.elem username installFor) {
  home = {
    file = {
      "${vscodeUserDir}/mcp.json".text = builtins.readFile ./mcp.json;
      "${vscodeUserDir}/prompts/copilot.instructions.md".text =
        builtins.readFile ./copilot.instructions.md;
      "${vscodeUserDir}/prompts/dummy.prompt.md".text = builtins.readFile ./copilot.instructions.md;
      "${vscodeUserDir}/prompts/dilbert.agent.md".text = builtins.readFile ./dilbert.agent.md;
      "${vscodeUserDir}/prompts/gonzales.agent.md".text = builtins.readFile ./gonzales.agent.md;
      "${vscodeUserDir}/prompts/linus.agent.md".text = builtins.readFile ./linus.agent.md;
      "${vscodeUserDir}/prompts/luthor.agent.md".text = builtins.readFile ./luthor.agent.md;
      "${vscodeUserDir}/prompts/nixpert.agent.md".text = builtins.readFile ./nixpert.agent.md;
      "${vscodeUserDir}/prompts/otto.agent.md".text = builtins.readFile ./otto.agent.md;
      "${vscodeUserDir}/prompts/penry.agent.md".text = builtins.readFile ./penry.agent.md;
      "${vscodeUserDir}/prompts/rosey.agent.md".text = builtins.readFile ./rosey.agent.md;
      "${vscodeUserDir}/prompts/velma.agent.md".text = builtins.readFile ./velma.agent.md;
      "${vscodeUserDir}/prompts/agent-create.prompt.md".text = builtins.readFile ./agent-create.prompt.md;
      "${vscodeUserDir}/prompts/agent-optimise.prompt.md".text =
        builtins.readFile ./agent-optimise.prompt.md;
      "${vscodeUserDir}/prompts/create-code.prompt.md".text = builtins.readFile ./create-code.prompt.md;
      "${vscodeUserDir}/prompts/create-conventional-commit.prompt.md".text =
        builtins.readFile ./create-conventional-commit.prompt.md;
      "${vscodeUserDir}/prompts/create-readme.prompt.md".text =
        builtins.readFile ./create-readme.prompt.md;
      "${vscodeUserDir}/prompts/offboard.prompt.md".text = builtins.readFile ./offboard.prompt.md;
      "${vscodeUserDir}/prompts/onboard.prompt.md".text = builtins.readFile ./onboard.prompt.md;
      "${vscodeUserDir}/prompts/orientate.prompt.md".text = builtins.readFile ./orientate.prompt.md;
      "${vscodeUserDir}/prompts/plan-code.prompt.md".text = builtins.readFile ./plan-code.prompt.md;
      "${vscodeUserDir}/prompts/plan-docs.prompt.md".text = builtins.readFile ./plan-docs.prompt.md;
      "${vscodeUserDir}/prompts/review-code.prompt.md".text = builtins.readFile ./review-code.prompt.md;
      "${vscodeUserDir}/prompts/review-naming.prompt.md".text =
        builtins.readFile ./review-naming.prompt.md;
      "${vscodeUserDir}/prompts/review-performance.prompt.md".text =
        builtins.readFile ./review-performance.prompt.md;
      "${vscodeUserDir}/prompts/review-pull-request-feedback.prompt.md".text =
        builtins.readFile ./review-pull-request-feedback.prompt.md;
      "${vscodeUserDir}/prompts/review-tests.prompt.md".text = builtins.readFile ./review-tests.prompt.md;
      "${vscodeUserDir}/prompts/update-docs.prompt.md".text = builtins.readFile ./update-docs.prompt.md;
    };
    packages = [
      pkgs.unstable.copilot-cli
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
          "chat.mcp.assisted.nuget.enabled" = false;
          "chat.mcp.autostart" = "newAndOutdated";
          "chat.mcp.gallery.enabled" = true;
          "chat.tools.terminal.blockDetectedFileWrites" = "never";
          "github.copilot.chat.anthropic.thinking.enabled" = true;
          "github.copilot.chat.codesearch.enabled" = true;
          "github.copilot.chat.commitMessageGeneration.instructions" = [
            {
              file = "${vscodeUserDir}/prompts/create-conventional-commit.prompt.md";
            }
          ];
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
