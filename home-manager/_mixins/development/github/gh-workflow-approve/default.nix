{
  bash,
  coreutils,
  gh,
  jq,
  lib,
  runCommand,
  shellcheck-minimal,
  writeShellApplication,
  ghBackend ? runCommand "gh-workflow-approve-gh" { } ''
    mkdir -p "$out/bin"
    ln -s ${gh}/bin/.gh-wrapped "$out/bin/gh-workflow-approve-gh"
  '',
}:
writeShellApplication {
  name = "gh-workflow-approve";
  runtimeInputs = [
    coreutils
    jq
  ];
  text = ''
    : "''${GH_WORKFLOW_APPROVE_GH_BIN:=${ghBackend}/bin/gh-workflow-approve-gh}"
  ''
  + builtins.readFile ./gh-workflow-approve.sh;
  derivationArgs = {
    postCheck =
      lib.optionalString shellcheck-minimal.compiler.bootstrapAvailable ''
        ${lib.getExe shellcheck-minimal} ${./gh-workflow-approve-tests.sh}
      ''
      + ''
        ${lib.getExe bash} ${./gh-workflow-approve-tests.sh} "$target"
      '';
  };
}
