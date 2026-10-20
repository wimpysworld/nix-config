{
  fetchFromGitHub,
  lib,
  stdenvNoCC,
}:

stdenvNoCC.mkDerivation {
  pname = "claude-themes-catppuccin";
  version = "0.2.1";

  src = fetchFromGitHub {
    owner = "matcra587";
    repo = "claude-themes";
    rev = "335b7713136662d8538b04dcde3369563bd620a6";
    hash = "sha256-ky7dgCpKVlIIxSXC9WO1TQv6Ue3/aVWTZHVsVWp3z2M=";
    sparseCheckout = [ "plugins/catppuccin" ];
  };

  dontUnpack = true;

  installPhase = ''
    runHook preInstall

    mkdir -p "$out"
    cp -R "$src/plugins/catppuccin/." "$out/"

    runHook postInstall
  '';

  meta = {
    description = "Catppuccin themes for Claude Code";
    homepage = "https://github.com/matcra587/claude-themes/tree/main/plugins/catppuccin";
    changelog = "https://github.com/matcra587/claude-themes/commits/main/plugins/catppuccin";
    license = lib.licenses.unfree;
    maintainers = with lib.maintainers; [ flexiondotorg ];
    platforms = lib.platforms.all;
  };
}
