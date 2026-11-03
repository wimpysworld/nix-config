{
  lib,
  fetchFromGitHub,
  rustPlatform,
}:

rustPlatform.buildRustPackage (finalAttrs: {
  pname = "weave";
  version = "0.5.0";

  src = fetchFromGitHub {
    owner = "matze";
    repo = "weave";
    tag = "v${finalAttrs.version}";
    hash = "sha256-RYlpjyQelwV5SBDskQ+3eQmByJEhMB+smbhwzkDcjZE=";
  };

  cargoHash = "sha256-qOckaRhd2vYwuEfyFaq9FiyzNjp61LE6+hKekLraEEg=";

  meta = {
    description = "Self-hosted web frontend to view and edit zk notes";
    homepage = "https://github.com/matze/weave";
    changelog = "https://github.com/matze/weave/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ flexiondotorg ];
    mainProgram = "weave";
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
  };
})
