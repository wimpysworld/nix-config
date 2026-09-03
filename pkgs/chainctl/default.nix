# Chainguard publish chainctl as prebuilt binaries only, one file per
# platform. Adapted from the pending nixpkgs pull request:
# https://github.com/NixOS/nixpkgs/pull/519985
{
  lib,
  stdenvNoCC,
  fetchurl,
  installShellFiles,
  versionCheckHook,
  writableTmpDirAsHomeHook,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "chainctl";
  version = "0.2.344";

  # Upstream installer: https://edu.chainguard.dev/chainguard/chainctl-usage/how-to-install-chainctl/
  src =
    finalAttrs.passthru.sources.${stdenvNoCC.hostPlatform.system}
      or (throw "chainctl: no binary available for ${stdenvNoCC.hostPlatform.system}");

  __structuredAttrs = true;
  strictDeps = true;

  dontUnpack = true;

  nativeBuildInputs = [
    installShellFiles
    writableTmpDirAsHomeHook
  ];

  installPhase = ''
    runHook preInstall
    install -Dm0755 "$src" "$out/bin/chainctl"

    # chainctl inspects argv[0] and acts as a Docker credential helper when
    # invoked as "docker-credential-cgr".
    ln -s chainctl "$out/bin/docker-credential-cgr"

    runHook postInstall
  '';

  postInstall = lib.optionalString (stdenvNoCC.buildPlatform.canExecute stdenvNoCC.hostPlatform) ''
    installShellCompletion --cmd chainctl \
      --bash <($out/bin/chainctl completion bash) \
      --fish <($out/bin/chainctl completion fish) \
      --zsh  <($out/bin/chainctl completion zsh)
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [ versionCheckHook ];
  versionCheckKeepEnvironment = [ "HOME" ];
  versionCheckProgramArg = "version";

  passthru.sources =
    let
      base = "https://dl.enforce.dev/chainctl/${finalAttrs.version}";
    in
    {
      x86_64-linux = fetchurl {
        url = "${base}/chainctl_linux_x86_64";
        hash = "sha256-bsj384z8sZ1T73AnvMQhT1jWO053LPGkS0XfNOaiAPc=";
      };
      aarch64-linux = fetchurl {
        url = "${base}/chainctl_linux_arm64";
        hash = "sha256-1h6odYDTYMBCvy/P0LbaaF4yP5TilBB6t8Xpzo7maX8=";
      };
      aarch64-darwin = fetchurl {
        url = "${base}/chainctl_darwin_arm64";
        hash = "sha256-hfAMtB+bjvMr0xPmjg+1OWWb1xT4pygy5pcOKvEn7lI=";
      };
    };

  meta = {
    description = "Command-line interface for the Chainguard platform";
    homepage = "https://edu.chainguard.dev/chainguard/chainctl/";
    downloadPage = "https://dl.enforce.dev/chainctl/";
    license = lib.licenses.unfree;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    maintainers = with lib.maintainers; [ flexiondotorg ];
    mainProgram = "chainctl";
    platforms = lib.attrNames finalAttrs.passthru.sources;
  };
})
