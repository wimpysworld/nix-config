{
  config,
  inputs,
  lib,
  noughtyLib,
  pkgs,
  ...
}:
let
  # The Slack workspace is a work account, so this mixin only applies where the
  # work profile lives. The `cg` tag marks those hosts.
  isWorkHost = noughtyLib.hostHasTag "cg";
  agentSlackPkg = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.agent-slack;

  # Wrap agent-slack so it reads the user's Slack token from sops-nix when
  # SLACK_TOKEN is not already set in the environment, and disables upstream
  # update checks on Nix-managed installations.
  agent-slack = pkgs.writeShellApplication {
    name = "agent-slack";
    text = ''
      export AGENT_SLACK_NO_UPDATE_CHECK=1
      token_file=${lib.escapeShellArg config.sops.secrets.slack-user-token.path}
      if [[ -z "''${SLACK_TOKEN:-}" && -r "$token_file" ]]; then
        SLACK_TOKEN="$(< "$token_file")"
        export SLACK_TOKEN
      fi
      exec ${lib.getExe agentSlackPkg} "$@"
    '';
  };
in
lib.mkIf isWorkHost {
  home.packages = [ agent-slack ];

  sops.secrets.slack-user-token = {
    sopsFile = ../../../../secrets/slack.yaml;
    key = "user_token";
    mode = "0400";
  };
}
