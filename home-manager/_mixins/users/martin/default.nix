{
  config,
  hostname,
  isLima,
  lib,
  pkgs,
  username,
  ...
}:
let
  inherit (pkgs.stdenv) isLinux;
  isStreamstation = hostname == "phasma" || hostname == "vader";
  gnupgSopsFile = ../../../../secrets/gnupg.yaml;
in
{
  home = {
    file.".face".source = ./face.png;
    file."Development/.keep" = lib.mkIf (!isLima) { text = ""; };
    file."Development/salsa/.envrc" = lib.mkIf (!isLima) {
      text = "export DEB_VENDOR=Debian";
    };
    file."Development/launchpad/.envrc" = lib.mkIf (!isLima) {
      text = "export DEB_VENDOR=Ubuntu";
    };
    file."Development/ubuntu/.envrc" = lib.mkIf (!isLima) {
      text = "export DEB_VENDOR=Ubuntu";
    };
    file."Development/ubuntu-mate/.envrc" = lib.mkIf (!isLima) {
      text = "export DEB_VENDOR=Ubuntu";
    };
    file."Games/.keep" = lib.mkIf (!isLima) { text = ""; };
    file."Websites/.keep" = lib.mkIf (!isLima) { text = ""; };
    file."Zero/.keep".text = "";
    file.".ssh/allowed_signers".text = ''
      martin@wimpress.org ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAywaYwPN4LVbPqkc+kUc7ZVazPBDy4LCAud5iGJdr7g9CwLYoudNjXt/98Oam5lK7ai6QPItK6ECj5+33x/iFpWb3Urr9SqMc/tH5dU1b9N/9yWRhE2WnfcvuI0ms6AXma8QGp1pj/DoLryPVQgXvQlglHaDIL1qdRWFqXUO2u30X5tWtDdOoR02UyAtYBttou4K0rG7LF9rRaoLYP9iCBLxkMJbCIznPD/pIYa6Fl8V8/OVsxYiFy7l5U0RZ7gkzJv8iNz+GG8vw2NX4oIJfAR4oIk3INUvYrKvI2NSMSw5sry+z818fD1hK+soYLQ4VZ4hHRHcf4WV4EeVa5ARxdw== Martin Wimpress
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
    sessionVariables = {
      DEBFULLNAME = "Martin Wimpress";
      DEBEMAIL = "code@wimpress.io";
      DEBSIGN_KEYID = "8F04688C17006782143279DA61DF940515E06DA3";
    };
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
    };
    fish.loginShellInit = ''
      ${pkgs.figurine}/bin/figurine -f "DOS Rebel.flf" $hostname
    '';
    git = {
      settings = {
        gpg = {
          ssh = {
            allowedSignersFile = "${config.home.homeDirectory}/.ssh/allowed_signers";
          };
        };
        user = {
          email = "martin@wimpress.org";
          name = "Martin Wimpress";
        };
      };
      signing = {
        format = "ssh";
        key = "${config.home.homeDirectory}/.ssh/id_rsa";
        signByDefault = true;
      };
    };
    lazygit.settings.git.commit = {
      # Add Signed-off-by trailer to commits (DCO compliance)
      signOff = true;
    };
  };
  # GPG private keys from sops-encrypted gnupg.yaml.
  # Public keys and trust are managed declaratively via programs.gpg.publicKeys above.
  sops.secrets = {
    gpg_private_0864983E.sopsFile = gnupgSopsFile;
    gpg_private_FFEE1E5C.sopsFile = gnupgSopsFile;
    gpg_private_15E06DA3.sopsFile = gnupgSopsFile;
  };
  systemd.user.tmpfiles = lib.mkIf (isLinux && !isLima) {
    rules = [
      "d ${config.home.homeDirectory}/Crypt 0755 ${username} users - -"
      "d ${config.home.homeDirectory}/Vaults/Armstrong 0755 ${username} users - -"
      "d ${config.home.homeDirectory}/Vaults/Secrets 0755 ${username} users - -"
    ];
  };
}
