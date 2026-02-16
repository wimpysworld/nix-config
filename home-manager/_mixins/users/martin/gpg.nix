{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (pkgs.stdenv) isLinux;
  # sopsFile requires an absolute path - use path type to resolve correctly
  gnupgSopsFile = ../../../../secrets/gnupg.yaml;
in
{
  home = {
    # Import GPG private keys from sops after public keys are in place.
    # Ordered after linkGeneration because Home Manager's importGpgKeys
    # (which handles publicKeys when mutableKeys = true) runs after linkGeneration.
    # See GnuPG.md Section 8 for the full technical rationale.
    activation.importGpgPrivateKeys = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      GPG="${pkgs.gnupg}/bin/gpg"

      for PRIVATE in \
        "${config.sops.secrets.gpg_private_0864983E.path}" \
        "${config.sops.secrets.gpg_private_FFEE1E5C.path}" \
        "${config.sops.secrets.gpg_private_15E06DA3.path}"; do
        if [ -f "$PRIVATE" ]; then
          $GPG --batch --yes --pinentry-mode loopback \
            --allow-secret-key-import --import "$PRIVATE" 2>/dev/null || true
        fi
      done
    '';
    # Configure gpg-agent SSH keys for Git signing
    file.".gnupg/sshcontrol" = {
      text = ''
        # SSH key for Git commit signing (id_rsa)
        # Keygrip for: ${config.home.homeDirectory}/.ssh/id_rsa
        EAC48EAAD36DC5B3460F9FC8FBD68DEED4DECD0F 0
      '';
      force = true;
    };
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
      scdaemonSettings = lib.mkIf isLinux {
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
