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
    rev = "bc389c57ab9c00211c79f83fdff15a9345e26e08";
    hash = "sha256-HdFF078JMRB1PySq+cv3I6j6EnvlMSP+4Cy1mbsVmwQ=";
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
