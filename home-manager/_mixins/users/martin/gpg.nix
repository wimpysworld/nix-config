{
  config,
  lib,
  noughtyLib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;
  # sopsFile requires an absolute path - use path type to resolve correctly
  gnupgSopsFile = ../../../../secrets/gnupg.yaml;
in
lib.mkIf (noughtyLib.isUser [ "martin" ]) {
  home = {
    # Import GPG private keys from sops after public keys are in place.
    # Ordered after linkGeneration because Home Manager's importGpgKeys
    # (which handles publicKeys when mutableKeys = true) runs after linkGeneration.
    # See GnuPG.md Section 8 for the full technical rationale.
    activation.importGpgPrivateKeys = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      GPG="${pkgs.gnupg}/bin/gpg"

      # Each entry pairs a key fingerprint with its secret file. A key that
      # already has secret material in the keyring is skipped, because a
      # repeat import makes gpg log "IMPORT_KEY failed: File exists".
      for ENTRY in \
        "5E7585ADFF106BFFBBA319DC654B877A0864983E:${config.sops.secrets.gpg_private_0864983E.path}" \
        "79F9461BF24B27F50DEB8A507454357CFFEE1E5C:${config.sops.secrets.gpg_private_FFEE1E5C.path}" \
        "8F04688C17006782143279DA61DF940515E06DA3:${config.sops.secrets.gpg_private_15E06DA3.path}"; do
        FPR="''${ENTRY%%:*}"
        PRIVATE="''${ENTRY#*:}"
        if [ -f "$PRIVATE" ] && ! $GPG --batch --list-secret-keys "$FPR" >/dev/null 2>&1; then
          $GPG --batch --yes --pinentry-mode loopback \
            --allow-secret-key-import --import "$PRIVATE" 2>/dev/null || true
        fi
      done
    '';
  };
  programs = {
    # Declarative GPG public keys and trust for Martin's keys.
    # mutableKeys must be true (the default) to allow private key import
    # to update pubring.kbx metadata. See GnuPG.md Section 8.3.
    gpg = {
      mutableKeys = true;
      mutableTrust = false;
      publicKeys = [
        {
          source = ./gpg-pubkey-0864983E.asc;
          trust = "full";
        }
        {
          source = ./gpg-pubkey-FFEE1E5C.asc;
          trust = "full";
        }
        {
          source = ./gpg-pubkey-15E06DA3.asc;
          trust = "ultimate"; # Primary key, used for DEBSIGN
        }
      ];
      # Prevent the PCSC-Lite conflicting with gpg-agent
      # https://wiki.nixos.org/wiki/Yubikey#Smartcard_mode
      scdaemonSettings = lib.mkIf host.is.linux {
        disable-ccid = true;
      };
    };
  };
  # GPG private keys from sops-encrypted gnupg.yaml.
  # Public keys and trust are managed declaratively via programs.gpg.publicKeys above.
  sops.secrets = {
    gpg_private_0864983E.sopsFile = gnupgSopsFile;
    gpg_private_FFEE1E5C.sopsFile = gnupgSopsFile;
    gpg_private_15E06DA3.sopsFile = gnupgSopsFile;
  };
}
