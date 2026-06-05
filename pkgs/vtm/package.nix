{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
  pkg-config,
  freetype,
  harfbuzz,
  lua5_4,
  lunasvg,
  plutovg,
  stb,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "vtm";
  version = "2026.05.30";

  src = fetchFromGitHub {
    owner = "directvt";
    repo = "vtm";
    rev = "v${finalAttrs.version}";
    hash = "sha256-R35CjF7bL/r1WTDe6hGA3muverh1pOE3MYF1rChVXUA=";
  };

  nativeBuildInputs = [
    cmake
    pkg-config
  ];

  buildInputs = [
    freetype
    harfbuzz
    lua5_4
    lunasvg
    plutovg
    stb
  ];

  cmakeFlags = [
    "-DSTB_INCLUDE_DIR=${stb}/include/stb"
    "-DFETCHCONTENT_FULLY_DISCONNECTED=ON"
    "-DFETCHCONTENT_UPDATES_DISCONNECTED=ON"
    "-DFETCHCONTENT_TRY_FIND_PACKAGE_MODE=ALWAYS"
  ];

  meta = {
    description = "Text-based desktop environment inside the terminal";
    homepage = "https://vtm.netxs.online/";
    license = lib.licenses.mit;
    mainProgram = "vtm";
    maintainers = [ lib.maintainers.flexiondotorg ];
    platforms = lib.platforms.unix;
  };
})
