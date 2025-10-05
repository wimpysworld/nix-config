{
  lib,
  stdenv,
  fetchFromGitHub,
  meson,
  libtsm,
  systemdLibs,
  libxkbcommon,
  libdrm,
  libGLU,
  libGL,
  pango,
  pixman,
  pkg-config,
  docbook_xsl,
  libxslt,
  libgbm,
  ninja,
  check,
  buildPackages,
}:
stdenv.mkDerivation {
  pname = "kmscon";
  version = "9.0.1-unstable-2025-10-03";

  src = fetchFromGitHub {
    owner = "Aetf";
    repo = "kmscon";
    rev = "1275f4466b58aead9b90f22800ec6fb13c599fa3";
    sha256 = "sha256-xEpO0/g0fXcaRbs+UrZxwD/iwl7nEZn4G/1woH8n7BA=";
  };

  strictDeps = true;

  depsBuildBuild = [
    buildPackages.stdenv.cc
  ];

  buildInputs = [
    libGLU
    libGL
    libdrm
    libtsm
    libxkbcommon
    pango
    pixman
    systemdLibs
    libgbm
    check
  ];

  nativeBuildInputs = [
    meson
    ninja
    docbook_xsl
    pkg-config
    libxslt # xsltproc
  ];

  env.NIX_CFLAGS_COMPILE =
    lib.optionalString stdenv.cc.isGNU "-O "
    + "-Wno-error=maybe-uninitialized -Wno-error=unused-result -Wno-error=implicit-function-declaration";

  enableParallelBuilding = true;

  patches = [
    ./auto-kbd-layout.patch # Update systemd dependencies so automatic keyboard layout configuration works
    ./sandbox.patch # Generate system units where they should be (nix store) instead of /etc/systemd/system
  ];

  meta = with lib; {
    description = "KMS/DRM based System Console";
    mainProgram = "kmscon";
    homepage = "https://www.freedesktop.org/wiki/Software/kmscon/";
    license = licenses.mit;
    maintainers = [ ];
    platforms = platforms.linux;
  };
}
