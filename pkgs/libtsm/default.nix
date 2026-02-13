{
  lib,
  stdenv,
  fetchFromGitHub,
  libxkbcommon,
  check,
  meson,
  ninja,
  pkg-config,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "libtsm";
  version = "4.4.2";

  src = fetchFromGitHub {
    owner = "kmscon";
    repo = "libtsm";
    rev = "v${finalAttrs.version}";
    sha256 = "sha256-DWy7kgBbXUEt2Htcugo8PaVoHE23Nu22EIrB5f6/P30=";
  };

  buildInputs = [
    libxkbcommon
  ];

  nativeBuildInputs = [
    check
    meson
    ninja
    pkg-config
  ];

  meta = with lib; {
    description = "Terminal-emulator State Machine";
    homepage = "https://www.freedesktop.org/wiki/Software/kmscon/libtsm/";
    license = licenses.mit;
    maintainers = [ flexiondotorg ];
    platforms = platforms.linux;
  };
})
