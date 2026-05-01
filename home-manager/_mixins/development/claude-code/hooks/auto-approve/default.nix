{ pkgs, ... }:
# Claude Code PreToolUse hook: auto-approve safe Bash invocations.
#
# Wired into `programs.claude-code.settings.hooks.PreToolUse` from the
# parent module so its package path is available via `lib.getExe`. See
# `auto-approve.sh` for the decision logic.
let
  name = "claude-auto-approve";
in
pkgs.writeShellApplication {
  inherit name;
  runtimeInputs = with pkgs; [
    jq
    coreutils
    gnused
  ];
  text = builtins.readFile ./auto-approve.sh;
}
