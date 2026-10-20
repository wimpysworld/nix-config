{
  lib,
  fetchFromGitHub,
  rustPlatform,
}:

rustPlatform.buildRustPackage (finalAttrs: {
  pname = "weave";
  version = "0.4.0";

  src = fetchFromGitHub {
    owner = "matze";
    repo = "weave";
    tag = "v${finalAttrs.version}";
    hash = "sha256-8Ecsc+GBQx/M9ytSpOYNleGfNVVVCjrCcBibhGgSNcY=";
  };

  cargoHash = "sha256-g5QM4EJUc79f2nXrKbNk7yeffRoEpOym2asqX5et1yQ=";

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
