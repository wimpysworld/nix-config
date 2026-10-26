# Home Manager joins every `home.activation` entry into one script, so an
# `exit` in one entry ends the whole activation before Home Manager records
# the current generation gcroot. The next switch then has no old generation,
# so sd-switch restarts every user unit and stale links stay in place.
#
# Gate: this assertion runs in every Home Manager evaluation and build,
# including `just build-home`, `just switch-home`, `just eval` and
# `just check`.
#
# The scan is a line heuristic, not a shell parser. A line fails when it
# starts with optional whitespace and the word `exit`, and it is outside a
# heredoc body, a function body and an open parenthesis (a subshell or a
# command substitution). An `exit` with a literal non-zero status passes,
# because it fails the switch visibly instead of silently. Unbalanced
# parentheses in `case` patterns can end a subshell scan early, so a
# deliberate exit that the heuristic misreads belongs in `allowedExits`.
{ config, lib, ... }:
let
  # Names of activation entries that exit early on purpose.
  allowedExits = [ ];

  count = pattern: line: (lib.length (builtins.split pattern line) - 1) / 2;
  matches = pattern: line: builtins.match pattern line != null;

  scanLine =
    state: line:
    if state.heredoc != null then
      state // lib.optionalAttrs (lib.trim line == state.heredoc) { heredoc = null; }
    else
      let
        isComment = matches "[[:space:]]*#.*" line;
        braces = if isComment then 0 else count "[{]" line - count "[}]" line;
        parens = if isComment then 0 else count "[(]" line - count "[)]" line;
        isFunctionHeader =
          matches "[[:space:]]*(function[[:space:]]+)?[A-Za-z_][A-Za-z0-9_:.-]*[[:space:]]*\\(\\)[[:space:]]*(\\{.*)?" line
          || matches "[[:space:]]*function[[:space:]]+[A-Za-z_][A-Za-z0-9_:.-]*[[:space:]]*(\\{.*)?" line;
        inFunction = state.function > 0 || state.pendingFunction || isFunctionHeader;
        function = if inFunction then lib.max 0 (state.function + braces) else 0;
        heredoc = builtins.match ".*[^<]<<-?[[:space:]]*['\"]?([A-Za-z_][A-Za-z0-9_]*)['\"]?.*" " ${line}";
        isExit =
          state.function == 0
          && !state.pendingFunction
          && state.parens == 0
          && matches "[[:space:]]*exit([[:space:];].*)?" line
          && !matches "[[:space:]]*exit[[:space:]]+[1-9][0-9]*[[:space:]]*([;#].*)?" line;
      in
      {
        inherit function;
        pendingFunction =
          (isFunctionHeader || state.pendingFunction) && function == 0 && count "[{]" line == 0;
        parens = lib.max 0 (state.parens + parens);
        heredoc = if heredoc == null then null else lib.head heredoc;
        exits = state.exits || isExit;
      };

  hasTopLevelExit =
    script:
    (lib.foldl' scanLine {
      function = 0;
      pendingFunction = false;
      parens = 0;
      heredoc = null;
      exits = false;
    } (lib.splitString "\n" script)).exits;

  offenders = lib.filter (
    name: !(lib.elem name allowedExits) && hasTopLevelExit config.home.activation.${name}.data
  ) (lib.attrNames config.home.activation);
in
{
  assertions = [
    {
      assertion = offenders == [ ];
      message = "home.activation entries with a top-level exit: ${lib.concatStringsSep ", " offenders}: use an if block, because exit ends the whole activation.";
    }
  ];
}
