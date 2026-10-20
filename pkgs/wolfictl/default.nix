{
  lib,
  stdenv,
  fetchurl,
}:

stdenv.mkDerivation rec {
  pname = "wolfictl";
  version = "0.39.29";

  src = fetchurl (
    let
      # Determine system and architecture
      currentSystem = stdenv.hostPlatform.parsed.kernel.name; # "linux", "darwin"
      currentArch = stdenv.hostPlatform.parsed.cpu.name; # "x86_64", "aarch64"
      # Map Nix architecture names to suffixes used in the URL
      archSuffix =
        if currentArch == "aarch64" then
          "arm64"
        else if currentArch == "x86_64" then
          "amd64"
        else
          throw "wolfictl: Unsupported architecture: ${currentArch}";

      # SHA256 sums from the release checksums.txt
      # https://github.com/wolfi-dev/wolfictl/releases/download/v${version}/wolfictl_checksums.txt
      sha256s = {
        "darwin_amd64" = "ace852e2877b333e555df178aff7d80d91521759d4733e1453b9f0328a7595a4";
        "darwin_arm64" = "cd3c87d662fca3eaef40ed4dab86b924cbaeafc97456b2dac025553301a62051";
        "linux_amd64" = "6b3d350e4b845de53a4e17c2ab816e2d045eed594a88d88ec966d6792ceb2de5";
        "linux_arm64" = "9b0dc187655d36cb2c767daebdc4faf5d104219b848103e8203a00896d8a21aa";
      };
      platformKey = "${currentSystem}_${archSuffix}";
    in
    {
      url = "https://github.com/wolfi-dev/wolfictl/releases/download/v${version}/wolfictl_${currentSystem}_${archSuffix}_${version}_${currentSystem}_${archSuffix}";
      # Look up the SHA256 sum; throw an error if not found for the current platform
      sha256 =
        sha256s.${platformKey} or (throw "wolfictl: SHA256 sum not available for platform ${platformKey}");
    }
  );

  # We are fetching a single binary file
  dontUnpack = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin
    install -Dm755 $src $out/bin/wolfictl
    runHook postInstall
  '';

  meta = with lib; {
    description = "A CLI used to work with the Wolfi OSS project";
    homepage = "https://github.com/wolfi-dev/wolfictl";
    license = licenses.asl20;
    platforms = platforms.linux ++ platforms.darwin;
    maintainers = [ maintainers.flexiondotorg ];
  };
}
