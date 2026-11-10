{
  lib,
  fetchurl,
  python3,
  stdenvNoCC,
  unzip,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "karoryfer-big-rusty-drums";
  version = "1.100";

  src = fetchurl {
    url = "https://github.com/sfzinstruments/karoryfer.big-rusty-drums/releases/download/v${finalAttrs.version}/Big_Rusty_Drums_1100.zip";
    hash = "sha256-1KmZCs0ZN22RzkRtrkFcgUKHKLWt67aojt27Omqsh0Q=";
  };

  nativeBuildInputs = [
    python3
    unzip
  ];
  dontUnpack = true;
  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/share/sfz/${finalAttrs.pname}"
    unzip -q "$src" -d "$out/share/sfz/${finalAttrs.pname}"
    ln -s Info_tab.png "$out/share/sfz/${finalAttrs.pname}/GUI/info_tab.png"
    python3 ${./sfizz-programs.py} create "$out/share/sfz/${finalAttrs.pname}"
    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    python3 ${./sfizz-programs.py} check "$out/share/sfz/${finalAttrs.pname}"
    runHook postInstallCheck
  '';

  meta = {
    description = "Sampled acoustic drums with sticks, brushes and mallets in SFZ format";
    homepage = "https://shop.karoryfer.com/pages/free-big-rusty-drums";
    license = lib.licenses.cc0;
    maintainers = with lib.maintainers; [ flexiondotorg ];
    platforms = lib.platforms.all;
  };
})
