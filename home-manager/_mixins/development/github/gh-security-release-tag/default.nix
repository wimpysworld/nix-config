{
  bash,
  coreutils,
  gh,
  gnugrep,
  jq,
  lib,
  python3,
  runCommand,
  shellcheck-minimal,
  writeShellApplication,
  ghBackend ? runCommand "gh-security-release-tag-gh" { } ''
    mkdir -p "$out/bin"
    ln -s ${gh}/bin/.gh-wrapped "$out/bin/gh-security-release-tag-gh"
  '',
}:
writeShellApplication {
  name = "gh-security-release-tag";
  runtimeInputs = [
    coreutils
    jq
    python3
  ];
  text = ''
    : "''${GH_SECURITY_RELEASE_TAG_GH_BIN:=${ghBackend}/bin/gh-security-release-tag-gh}"
  ''
  + builtins.readFile ./gh-security-release-tag.sh;
  derivationArgs = {
    nativeBuildInputs = [
      coreutils
      gnugrep
      jq
      python3
    ];
    postCheck =
      lib.optionalString shellcheck-minimal.compiler.bootstrapAvailable ''
        ${lib.getExe shellcheck-minimal} ${./gh-security-release-tag-tests.sh}
      ''
      + ''
        ${lib.getExe bash} ${./gh-security-release-tag-tests.sh} "$target"
      '';
  };
}
