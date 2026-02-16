{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (pkgs.stdenv) isDarwin;
  # sopsFile requires an absolute path - use path type to resolve correctly
  keysSopsFile = ../../../../secrets/ssh.yaml;
  # Helper function to generate SSH key secret definitions
  mkSshKeySecrets = keyNamePrefix: sshBaseName: {
    "${keyNamePrefix}_${sshBaseName}" = {
      sopsFile = keysSopsFile;
      path = "${config.home.homeDirectory}/.ssh/${keyNamePrefix}_${sshBaseName}";
    };
    "${keyNamePrefix}_${sshBaseName}_pub" = {
      sopsFile = keysSopsFile;
      path = "${config.home.homeDirectory}/.ssh/${keyNamePrefix}_${sshBaseName}.pub";
      mode = "0644";
    };
  };
  # List of ed25519_sk base names
  ed25519SkKeyIdentifiers = [
    "28L"
    "45L"
    "bane"
    "keyring"
    "phasma"
    "vader"
  ];
  # Generate the attribute set for all ed25519_sk key secrets
  allEd25519SkSecrets = lib.foldl lib.recursiveUpdate { } (
    map (baseName: mkSshKeySecrets "id_ed25519_sk" baseName) ed25519SkKeyIdentifiers
  );
in
{
  home = {
    # SSH allowed signers for Git verification
    file.".ssh/allowed_signers".text = ''
      ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAywaYwPN4LVbPqkc+kUc7ZVazPBDy4LCAud5iGJdr7g9CwLYoudNjXt/98Oam5lK7ai6QPItK6ECj5+33x/iFpWb3Urr9SqMc/tH5dU1b9N/9yWRhE2WnfcvuI0ms6AXma8QGp1pj/DoLryPVQgXvQlglHaDIL1qdRWFqXUO2u30X5tWtDdOoR02UyAtYBttou4K0rG7LF9rRaoLYP9iCBLxkMJbCIznPD/pIYa6Fl8V8/OVsxYiFy7l5U0RZ7gkzJv8iNz+GG8vw2NX4oIJfAR4oIk3INUvYrKvI2NSMSw5sry+z818fD1hK+soYLQ4VZ4hHRHcf4WV4EeVa5ARxdw== Martin Wimpress
    '';
    # Darwin openssh for FIDO2 support
    packages = lib.optionals isDarwin [ pkgs.openssh ];
  };

  programs = {
    fish = lib.mkIf isDarwin {
      shellAliases = {
        ssh-agent-start = "eval (${pkgs.openssh}/bin/ssh-agent -c)";
        ssh-agent-stop = "${pkgs.openssh}/bin/ssh-agent -k";
      };
    };
    ssh = lib.mkIf isDarwin {
      enable = true;
      enableDefaultConfig = false;
      includes = [
        "${config.home.homeDirectory}/.ssh/local_config"
      ];
      matchBlocks."*" = {
        addKeysToAgent = "yes";
      };
      package = pkgs.openssh;
    };
  };

  sops.secrets = allEd25519SkSecrets // {
    ssh_config = {
      sopsFile = keysSopsFile;
      path =
        if isDarwin then
          "${config.home.homeDirectory}/.ssh/local_config"
        else
          "${config.home.homeDirectory}/.ssh/config";
    };
    ssh_key = {
      sopsFile = keysSopsFile;
      path = "${config.home.homeDirectory}/.ssh/id_rsa";
    };
    ssh_pub = {
      sopsFile = keysSopsFile;
      path = "${config.home.homeDirectory}/.ssh/id_rsa.pub";
    };
    ssh_semaphore_key = {
      sopsFile = keysSopsFile;
      path = "${config.home.homeDirectory}/.ssh/id_rsa_semaphore";
    };
    ssh_semaphore_pub = {
      sopsFile = keysSopsFile;
      path = "${config.home.homeDirectory}/.ssh/id_rsa_semaphore.pub";
    };
  };
}
