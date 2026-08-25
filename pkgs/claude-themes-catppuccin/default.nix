{
  fetchFromGitHub,
  lib,
  stdenvNoCC,
}:

stdenvNoCC.mkDerivation {
  pname = "claude-themes-catppuccin";
  version = "0.2.0";

  src = fetchFromGitHub {
    owner = "matcra587";
    repo = "claude-themes";
    rev = "30b1864fc4b38c7ebd8f48ed1ccdc3e47a74b639";
    hash = "sha256-VY3XZal7ovh2uIY7fm7btpJ7llEv3OWYp1Nnz1+s7c4=";
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
