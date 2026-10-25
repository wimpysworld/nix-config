{
  pkgs,
  lib,
  defaults,
  managed,
}:
let
  defaultsFile = pkgs.writeText "handy-defaults.json" (builtins.toJSON { settings = defaults; });
  managedFile = pkgs.writeText "handy-managed.json" (builtins.toJSON managed);
  makeLauncher =
    binary: extraCheckCommand:
    pkgs.writeShellApplication {
      name = "handy";
      runtimeInputs = with pkgs; [
        coreutils
        glib
        jq
        systemd
        util-linux
      ];
      derivationArgs.postCheck = extraCheckCommand;
      text = ''
        handy_bin=${lib.escapeShellArg binary}
        defaults_file=${defaultsFile}
        managed_file=${managedFile}
      ''
      + builtins.readFile ./handy.sh;
    };
  python = pkgs.python3.withPackages (ps: [
    ps.dbus-python
    ps.pygobject3
  ]);
  stub = pkgs.writeShellApplication {
    name = "handy-stub";
    text = ''
      exec ${lib.getExe python} ${./stub.py} "$@"
    '';
  };
  testLauncher = makeLauncher (lib.getExe stub) "";
  tests = pkgs.runCommand "handy-launcher-tests" { nativeBuildInputs = [ pkgs.dbus ]; } ''
    dbus-run-session --config-file=${pkgs.dbus}/share/dbus-1/session.conf -- \
      ${lib.getExe python} ${./test.py} \
      ${lib.getExe testLauncher} ${managedFile} ${defaultsFile}
    touch "$out"
  '';
  launcher = makeLauncher (lib.getExe pkgs.handy) ''
    test -e ${tests}
  '';
in
pkgs.symlinkJoin {
  name = "handy-managed-${pkgs.handy.version}";
  inherit (pkgs.handy) meta;
  paths = [ pkgs.handy ];
  passthru = {
    inherit
      tests
      launcher
      managedFile
      defaultsFile
      ;
  };
  postBuild = ''
    ln -sfn ${lib.getExe launcher} "$out/bin/handy"
    substitute ${pkgs.handy}/share/applications/Handy.desktop "$TMPDIR/Handy.desktop" \
      --replace-fail "Exec=handy" "Exec=$out/bin/handy"
    mv -T "$TMPDIR/Handy.desktop" "$out/share/applications/Handy.desktop"
  '';
}
