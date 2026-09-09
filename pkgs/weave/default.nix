{
  lib,
  fetchFromGitHub,
  rustPlatform,
}:

rustPlatform.buildRustPackage (finalAttrs: {
  pname = "weave";
  version = "0.1.0";

  src = fetchFromGitHub {
    owner = "matze";
    repo = "weave";
    tag = "v${finalAttrs.version}";
    hash = "sha256-T6NNRNRKlBUyTJeesfjPq0k77hSNsPwCXIXUkSJtw48=";
  };

  cargoHash = "sha256-z3H6Ek2S/FRrVg/TOJj2o0ZYDLo2AvYq5+RMH/wl1Cs=";

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
