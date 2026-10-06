{
  lib,
  fetchFromGitHub,
  rustPlatform,
}:

rustPlatform.buildRustPackage (finalAttrs: {
  pname = "weave";
  version = "0.2.2";

  src = fetchFromGitHub {
    owner = "matze";
    repo = "weave";
    tag = "v${finalAttrs.version}";
    hash = "sha256-RPNfjuZtWidCFmlJIvy0Lnb9Oi/lQoDurlAM+fMq8po=";
  };

  cargoHash = "sha256-ZwqLIGFPmsOpR4JqIfQXMI/TO2XgHggwRhWqLsXhHmk=";

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
