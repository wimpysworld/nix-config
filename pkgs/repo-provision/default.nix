{
  lib,
  bash,
  coreutils,
  git,
  jq,
  writeShellApplication,
  runCommand,
}:
let
  tests =
    runCommand "repo-provision-tests"
      {
        nativeBuildInputs = [
          bash
          coreutils
          jq
        ];
      }
      ''
        bash ${./test-repo-provision.sh} ${./repo-provision.sh}
        touch "$out"
      '';
in
writeShellApplication {
  name = "repo-provision";
  runtimeInputs = [
    git
    jq
    coreutils
  ];
  text = builtins.readFile ./repo-provision.sh;
  derivationArgs = {
    passthru = { inherit tests; };
    postCheck = "test -e ${tests}";
  };
  meta = {
    description = "Clone missing organisation repositories and fetch existing checkouts";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
    mainProgram = "repo-provision";
  };
}
