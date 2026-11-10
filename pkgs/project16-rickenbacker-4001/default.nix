{
  lib,
  fetchFromGitHub,
  stdenvNoCC,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "project16-rickenbacker-4001";
  version = "0-unstable-2020-06-27";

  src = fetchFromGitHub {
    owner = "sfzinstruments";
    repo = "Project16Rickenbacker4001";
    rev = "9049f4d88a8ce8b9e5d5a9a71f03e7bcfbf88f08";
    hash = "sha256-8AW416vfY8vX2fzICyCJTKuaP181BxiYP9R8+YOvvkY=";
  };

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/share/sfz/${finalAttrs.pname}"
    cp -r ./. "$out/share/sfz/${finalAttrs.pname}/"
    runHook postInstall
  '';

  meta = {
    description = "Rickenbacker 4001 bass with fingered, picked, muted and slap SFZ programs";
    homepage = "https://github.com/sfzinstruments/Project16Rickenbacker4001";
    license = {
      fullName = "CC BY-NC-SA 3.0 with commercial music permission and sample library restrictions";
      url = "https://github.com/sfzinstruments/Project16Rickenbacker4001/blob/9049f4d88a8ce8b9e5d5a9a71f03e7bcfbf88f08/README.md";
      free = false;
      redistributable = true;
    };
    maintainers = with lib.maintainers; [ flexiondotorg ];
    platforms = lib.platforms.all;
  };
})
