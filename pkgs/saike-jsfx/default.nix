{
  fetchFromGitHub,
  lib,
  stdenvNoCC,
}:

stdenvNoCC.mkDerivation {
  pname = "saike-jsfx";
  version = "0-unstable-2026-11-04";

  src = fetchFromGitHub {
    owner = "JoepVanlier";
    repo = "JSFX";
    rev = "c1c98b5f5f505238ac4d21ee43f32daf6b885527";
    hash = "sha256-6Wm2WfLPpDYbXf8VNtJQRdoyIDpJww1Pm80mGEaepbQ=";
    sparseCheckout = [
      "Filther"
      "Squashman"
      "LICENSE"
    ];
  };

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/share/reaper/Effects/Saike"
    cp -r Filther Squashman LICENSE "$out/share/reaper/Effects/Saike/"

    runHook postInstall
  '';

  meta = {
    description = "Filther and Squashman JSFX effects for REAPER";
    homepage = "https://github.com/JoepVanlier/JSFX";
    license = lib.licenses.mit;
    platforms = lib.platforms.all;
  };
}
