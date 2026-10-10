# Runs the Communication Rules hook suites: the scanner fixtures, the state
# suites, and the Pi extractor tests. The suites use only the Python standard
# library, temporary strike directories, and the fallback policy, so they run
# hermetically in the build sandbox.
# Gate: `nix build .#checks.<system>.communication-rules-hooks`, run by
# `just check` and CI.
{ lib, pkgs }:
let
  agentic = ../../home-manager/_mixins/agentic;
  src = lib.fileset.toSource {
    root = agentic;
    fileset = lib.fileset.unions [
      (agentic + "/hooks/communication-rules")
      (agentic + "/assistants/styles/house-style/house-style.md")
    ];
  };
in
pkgs.runCommand "communication-rules-hooks" { nativeBuildInputs = [ pkgs.python3 ]; } ''
  export HOME="$TMPDIR/home"
  export XDG_RUNTIME_DIR="$TMPDIR/runtime"
  export PI_CODING_AGENT_DIR="$TMPDIR/pi-agent"
  mkdir -p "$HOME" "$XDG_RUNTIME_DIR" "$PI_CODING_AGENT_DIR"
  cd ${src}/hooks/communication-rules/tests
  export PYTHONDONTWRITEBYTECODE=1
  for suite in run-scanner-fixtures.py test_*.py; do
    echo "Running $suite"
    python3 "$suite"
  done
  touch "$out"
''
