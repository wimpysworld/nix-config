{
  config,
  lib,
  noughtyLib,
  pkgs,
  ...
}:
let
  # The Slack workspace is a work account, so this mixin only applies where the
  # work profile lives. The `workspace` tag marks those hosts.
  isWorkHost = noughtyLib.hostHasTag "workspace";

  # Post one message to Slack as the token owner. The Slack MCP server posts
  # through Anthropic's Slack app, so Slack stamps those messages with a
  # "Sent using @Claude" attribution that no local setting removes, and renders
  # them through Block Kit, which leaves a custom emote as literal text. This
  # helper posts with the user's own OAuth token instead. Only chat.postMessage
  # and conversations.open are reachable, both held as fixed strings, and the
  # script validates every argument. It never edits and never deletes, although
  # a user token grants both. See `slack-post.sh` for the policy details and
  # `slack-post-tests.sh` for the runnable policy test.
  slack-post = pkgs.writeShellApplication {
    name = "slack-post";
    runtimeInputs = with pkgs; [
      coreutils
      curl
      gnugrep
      jq
    ];
    text = ''
      readonly SLACK_POST_TOKEN_FILE=${lib.escapeShellArg config.sops.secrets.slack-user-token.path}
    ''
    + builtins.readFile ./slack-post.sh;
  };
in
lib.mkIf isWorkHost {
  home.packages = [ slack-post ];

  sops.secrets.slack-user-token = {
    sopsFile = ../../../../secrets/slack.yaml;
    key = "user_token";
    mode = "0400";
  };
}
