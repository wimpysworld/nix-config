{
  lib,
  pkgs,
  python3,
  runCommand,
  writeShellApplication,
  writeText,
}:
let
  manifest = import ./manifest.nix {
    inherit lib pkgs;
  };
  manifestFile = writeText "agentic-dots-manifest.json" (builtins.toJSON manifest + "\n");
  application = writeShellApplication {
    name = "export-agentic-dots";
    runtimeInputs = [ python3 ];
    text = ''
      export AGENTIC_DOTS_MANIFEST=${manifestFile}
      exec python3 ${./exporter.py} "$@"
    '';
    meta = {
      description = "Export public assistant resources into a review tree";
      license = lib.licenses.blueOak100;
      mainProgram = "export-agentic-dots";
      platforms = lib.platforms.all;
    };
  };
  testPython = python3.withPackages (pythonPackages: [ pythonPackages.pyyaml ]);
  tests =
    runCommand "export-agentic-dots-test"
      {
        nativeBuildInputs = [ testPython ];
        AGENTIC_DOTS_TEST_CANONICAL_PI = ../../home-manager/_mixins/agentic/pi/default.nix;
        AGENTIC_DOTS_TEST_COMMAND = lib.getExe application;
        AGENTIC_DOTS_TEST_EXPORTER = ./exporter.py;
        AGENTIC_DOTS_TEST_MANIFEST = manifestFile;
      }
      ''
        export HOME="$TMPDIR/home"
        export PYTHONDONTWRITEBYTECODE=1
        python ${./tests/test_exporter.py}
        touch "$out"
      '';
in
application.overrideAttrs (old: {
  passthru = (old.passthru or { }) // {
    inherit manifestFile tests;
  };
})
