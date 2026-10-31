{
  fetchurl,
  lib,
  linkFarm,
  python3,
  runCommand,
  writeShellApplication,
}:
let
  avatars = linkFarm "private-matrix-avatars" {
    "martin.png" = fetchurl {
      name = "martin-avatar.png";
      url = "https://avatars.githubusercontent.com/u/304639?v=4";
      hash = "sha256-8jqDjzFKdka2nS61Ycqc2gaLDNHr2/P48++ct/no0rQ=";
    };
    "skrye.jpg" = fetchurl {
      name = "skrye-avatar.jpg";
      url = "https://avatars.githubusercontent.com/u/275224056?v=4";
      hash = "sha256-HuPZGNb5+Wd8XdVmoCRTQ+tgrLAfunIZC703Oh4y+uQ=";
    };
    "zannah.jpg" = fetchurl {
      name = "zannah-avatar.jpg";
      url = "https://avatars.githubusercontent.com/u/275226461?v=4";
      hash = "sha256-cJkSr6koeAaVZaiWz2SHSHv229CxpGmp7fCmdtFnBV0=";
    };
    "traya.jpg" = fetchurl {
      name = "traya-avatar.jpg";
      url = "https://avatars.githubusercontent.com/u/275627262?v=4";
      hash = "sha256-dLZSkSgYdlYJiLOPCCK9FJaxerhPTvRC5aiCBW2cIts=";
    };
    "the-cauldron.jpg" = fetchurl {
      name = "the-cauldron-avatar.jpg";
      url = "https://avatars.githubusercontent.com/u/275220945?v=4";
      hash = "sha256-H88IEnvG5RDA6hTgVZ0fIC1cXjUFfv+hne3EW16UHLA=";
    };
  };
  application = writeShellApplication {
    name = "private-matrix-bootstrap";
    runtimeInputs = [ python3 ];
    text =
      builtins.replaceStrings
        [
          "@AVATARS@"
          "@BOOTSTRAP@"
        ]
        [
          "${avatars}"
          "${./bootstrap.py}"
        ]
        (builtins.readFile ./private-matrix-bootstrap.sh);
    meta = {
      description = "Idempotent provisioning for the private Matrix room";
      license = lib.licenses.mit;
      mainProgram = "private-matrix-bootstrap";
      platforms = lib.platforms.linux;
    };
  };
  tests = runCommand "private-matrix-bootstrap-tests" { nativeBuildInputs = [ python3 ]; } ''
    export PYTHONDONTWRITEBYTECODE=1
    export PRIVATE_MATRIX_AVATARS_DIR="${avatars}"
    cp ${./bootstrap.py} bootstrap.py
    cp ${./test_bootstrap.py} test_bootstrap.py
    python3 -m unittest -v test_bootstrap
    touch "$out"
  '';
in
application.overrideAttrs (old: {
  passthru = (old.passthru or { }) // {
    inherit avatars tests;
  };
})
