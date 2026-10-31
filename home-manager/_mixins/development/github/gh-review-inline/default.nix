{
  bash,
  coreutils,
  gh,
  jq,
  lib,
  runCommand,
  shellcheck-minimal,
  writeShellApplication,
  ghBackend ? runCommand "gh-review-inline-gh" { } ''
    mkdir -p "$out/bin"
    ln -s ${gh}/bin/.gh-wrapped "$out/bin/gh-review-inline-gh"
  '',
}:
writeShellApplication {
  name = "gh-review-inline";
  runtimeInputs = [
    coreutils
    jq
  ];
  text = ''
    : "''${GH_REVIEW_INLINE_GH_BIN:=${ghBackend}/bin/gh-review-inline-gh}"
  ''
  + builtins.readFile ./gh-review-inline.sh;
  derivationArgs = {
    nativeBuildInputs = [ jq ];
    postCheck =
      lib.optionalString shellcheck-minimal.compiler.bootstrapAvailable ''
        ${lib.getExe shellcheck-minimal} ${./gh-review-inline-tests.sh}
      ''
      + ''
        ${lib.getExe bash} ${./gh-review-inline-tests.sh} "$target"
      '';
  };
}
