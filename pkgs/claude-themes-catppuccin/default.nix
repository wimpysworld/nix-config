{
  fetchFromGitHub,
  lib,
  stdenvNoCC,
}:

stdenvNoCC.mkDerivation {
  pname = "claude-themes-catppuccin";
  version = "0.2.2";

  src = fetchFromGitHub {
    owner = "matcra587";
    repo = "claude-themes";
    rev = "d9de2d4e12ba27dde79979552e002566bf9194f1";
    hash = "sha256-c4IzT4g5WuGX1+7i4KTopEd/u21fJIiDNYSTciTnEOU=";
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
