{
  lib,
  python3,
  writeShellApplication,
  runCommand,
}:
let
  tests = runCommand "repo-provision-tests" { nativeBuildInputs = [ python3 ]; } ''
    export PYTHONDONTWRITEBYTECODE=1
    cp ${./repo_provision.py} repo_provision.py
    cp ${./test_repo_provision.py} test_repo_provision.py
    python3 -m unittest -v test_repo_provision
    touch "$out"
  '';
in
writeShellApplication {
  name = "repo-provision";
  runtimeInputs = [ python3 ];
  text = ''
    exec python3 -I ${./repo_provision.py} "$@"
  '';
  derivationArgs = {
    passthru = { inherit tests; };
    doCheck = true;
    checkPhase = "test -e ${tests}";
  };
  meta = {
    description = "Read-only GitHub repository inventory planner";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
    mainProgram = "repo-provision";
  };
}
