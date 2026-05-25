## Update Slash Command

Load the `write-command` skill and run its **update** flow on the target.

Command path argument: $ARGUMENTS. If blank, ask for the command directory or `prompt.md` path.

Apply `write-command`: diagnose body shape, headers per provider, argument-hint, argument substitution (`$ARGUMENTS` vs `$1`), and side-effect declaration; preserve `description.txt` unless wrong; emit the changed files plus a short changelog. Do not duplicate that guidance here.
