{
  lib,
  fetchurl,
  stdenvNoCC,
  unrar,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "unreal-the-slapper";
  version = "0-unstable-2019-03-12";

  src = fetchurl {
    name = "Ui_The_Slapper.rar";
    url = "https://drive.usercontent.google.com/download?id=1YmHJuK_98V4nBzahUX_o5XaJiy_hE_bU&export=download&confirm=t";
    hash = "sha256-0WyujwhwCtW70UbEaU9ZZUkEEJi431vKVcNBf0aeOKs=";
    meta.license = lib.licenses.unfree;
  };

  nativeBuildInputs = [ unrar ];
  env.LC_ALL = "C.UTF-8";
  unpackPhase = ''
    runHook preUnpack
    unrar x -idq "$src"
    runHook postUnpack
  '';
  dontConfigure = true;
  dontBuild = true;
  preferLocalBuild = true;
  allowSubstitutes = false;

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/share/sfz/${finalAttrs.pname}"
    cp -r Ui_The_Slapper/. "$out/share/sfz/${finalAttrs.pname}/"
    runHook postInstall
  '';

  meta = {
    description = "Electric and acoustic slap guitars with fingerpicking articulations in SFZ format";
    homepage = "https://unreal-instruments.wixsite.com/unreal-instruments/the-slapper";
    license = lib.licenses.unfree;
    maintainers = with lib.maintainers; [ flexiondotorg ];
    platforms = lib.platforms.all;
  };
})
