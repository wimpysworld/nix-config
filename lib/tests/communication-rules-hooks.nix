# Runs the Communication Rules scanner, state, extraction and client suites.
# The tests use temporary state and local processes. They contact no provider.
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
      (agentic + "/pi/extensions/communication-rules/index.ts")
      (agentic + "/opencode/plugins/communication-rules.ts")
      (agentic + "/opencode/plugins/communication-rules.test.ts")
    ];
  };
in
pkgs.runCommand "communication-rules-hooks"
  {
    nativeBuildInputs = [
      pkgs.python3
      pkgs.nodejs
      pkgs.bun
    ];
  }
  ''
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
    node --test pi-shim.test.ts
    bun test opencode-shim.test.ts ${src}/opencode/plugins/communication-rules.test.ts
    touch "$out"
  ''
