{
  lib,
  buildGoModule,
  fetchFromGitHub,
}:

buildGoModule (finalAttrs: {
  pname = "tcount";
  version = "0.7.0";

  src = fetchFromGitHub {
    owner = "lancekrogers";
    repo = "tcount";
    rev = "v${finalAttrs.version}";
    hash = "sha256-mmLNyDeSsNbkBbXnSDYpzYvLGKaX2T1hxewQY4WMzvM=";
  };

  vendorHash = "sha256-lPOzlm6Ko0GsKSSwyeRwroeOcLEyNEfzD8ObIyyec5c=";

  subPackages = [ "cmd/tcount" ];

  ldflags = [
    "-s"
    "-w"
    "-X main.version=${finalAttrs.version}"
  ];

  meta = {
    description = "Fast, zero-network token counter for LLM workflows";
    homepage = "https://github.com/lancekrogers/tcount";
    license = lib.licenses.mit;
    mainProgram = "tcount";
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
  };
})
