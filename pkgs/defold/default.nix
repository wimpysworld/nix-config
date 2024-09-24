{
  autoPatchelfHook,
  fetchurl,
  lib,
  stdenv,
  freetype,
  jdk17,
  libffi_3_3,
  libGLU,
  libX11,
  libXi,
  libXrender,
  libXtst,
  libXxf86vm,
  openal,
  zlib,
}:
stdenv.mkDerivation rec {
  pname = "defold";
  version = "1.9.3";

  src = fetchurl {
    url = "https://github.com/defold/defold/releases/download/${version}/Defold-x86_64-linux.tar.gz";
    hash = "sha256-SU0e0rChzmBguM6XR7xrZbnF27ZJ3yORw7Y+gnElDbI=";
  };

  nativeBuildInputs = [ autoPatchelfHook ];
  buildInputs = [
    freetype
    jdk17
    libffi_3_3
    libGLU
    libX11
    libXi
    libXrender
    libXtst
    libXxf86vm
    openal
    zlib
  ];

  dontBuild = true;
  dontConfigure = true;

  installPhase = ''
    runHook preInstall
    cp -a . $out
    runHook postInstall
  '';

  meta = {
    description = "A completely free to use game engine for development of desktop, mobile and web games.";
    homepage = "https://www.defold.com";
    license = lib.licenses.free;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    maintainers = with lib.maintainers; [ flexiondotorg ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "Defold";
  };
}
