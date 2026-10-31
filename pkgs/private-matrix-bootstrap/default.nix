{
  lib,
  python3,
  runCommand,
  writeShellApplication,
}:
let
  application = writeShellApplication {
    name = "private-matrix-bootstrap";
    runtimeInputs = [ python3 ];
    text = builtins.replaceStrings [ "@BOOTSTRAP@" ] [ "${./bootstrap.py}" ] (
      builtins.readFile ./private-matrix-bootstrap.sh
    );
    meta = {
      description = "Idempotent provisioning for the private Matrix room";
      license = lib.licenses.mit;
      mainProgram = "private-matrix-bootstrap";
      platforms = lib.platforms.linux;
    };
  };
  tests = runCommand "private-matrix-bootstrap-tests" { nativeBuildInputs = [ python3 ]; } ''
    export PYTHONDONTWRITEBYTECODE=1
    cp ${./bootstrap.py} bootstrap.py
    cp ${./test_bootstrap.py} test_bootstrap.py
    python3 -m unittest -v test_bootstrap
    touch "$out"
  '';
in
application.overrideAttrs (old: {
  passthru = (old.passthru or { }) // {
    inherit tests;
  };
})
