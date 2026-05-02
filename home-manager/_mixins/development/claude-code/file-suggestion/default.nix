{ pkgs, ... }:
# Claude Code `fileSuggestion` command: replaces the broken built-in `@` picker
# with `fd | fzf --filter`. Wired into `programs.claude-code.settings.fileSuggestion`
# from the parent module via `lib.getExe`. See `file-suggestion.sh` for the
# selection logic.
let
  name = "claude-file-suggestion";
in
pkgs.writeShellApplication {
  inherit name;
  runtimeInputs = with pkgs; [
    fd
    fzf
    coreutils
    gnused
    gawk
  ];
  text = builtins.readFile ./file-suggestion.sh;
}
