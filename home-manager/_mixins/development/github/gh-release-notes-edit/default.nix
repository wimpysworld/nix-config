{
  bash,
  coreutils,
  gh,
  gnugrep,
  jq,
  lib,
  libiconvReal,
  runCommand,
  shellcheck-minimal,
  writeShellApplication,
  ghBackend ? runCommand "gh-release-notes-edit-gh" { } ''
    mkdir -p "$out/bin"
    ln -s ${gh}/bin/.gh-wrapped "$out/bin/gh-release-notes-edit-gh"
  '',
}:
writeShellApplication {
  name = "gh-release-notes-edit";
  runtimeInputs = [
    coreutils
    gnugrep
    jq
    libiconvReal
  ];
  text = ''
    readonly GH_RELEASE_NOTES_EDIT_GH_BIN=${lib.escapeShellArg "${ghBackend}/bin/gh-release-notes-edit-gh"}
  ''
  + builtins.readFile ./gh-release-notes-edit.sh;
  derivationArgs = {
    nativeBuildInputs = [
      coreutils
      gnugrep
      jq
      libiconvReal
    ];
    postCheck =
      lib.optionalString shellcheck-minimal.compiler.bootstrapAvailable ''
        ${lib.getExe shellcheck-minimal} ${./gh-release-notes-edit-tests.sh}
      ''
      + ''
        ${lib.getExe bash} ${./gh-release-notes-edit-tests.sh} "$target" ${./gh-release-notes-edit.sh}
      '';
  };
}
