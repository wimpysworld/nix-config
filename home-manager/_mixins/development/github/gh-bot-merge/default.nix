{
  bash,
  coreutils,
  gh,
  jq,
  lib,
  runCommand,
  shellcheck-minimal,
  writeShellApplication,
  ghBackend ? runCommand "gh-bot-merge-gh" { } ''
    mkdir -p "$out/bin"
    ln -s ${gh}/bin/.gh-wrapped "$out/bin/gh-bot-merge-gh"
  '',
}:
writeShellApplication {
  name = "gh-bot-merge";
  runtimeInputs = [
    coreutils
    jq
  ];
  text = ''
    : "''${GH_BOT_MERGE_GH_BIN:=${ghBackend}/bin/gh-bot-merge-gh}"
  ''
  + builtins.readFile ./gh-bot-merge.sh;
  derivationArgs = {
    nativeBuildInputs = [ jq ];
    postCheck =
      lib.optionalString shellcheck-minimal.compiler.bootstrapAvailable ''
        ${lib.getExe shellcheck-minimal} ${./gh-bot-merge-tests.sh}
      ''
      + ''
        ${lib.getExe bash} ${./gh-bot-merge-tests.sh} "$target"
      '';
  };
}
