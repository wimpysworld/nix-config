{ config, ... }:
{
  home = {
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
      GITSIGN_CONNECTOR_ID = "https://accounts.google.com";
    };
  };

  programs = {
    git = {
      settings = {
        gpg = {
          ssh = {
            allowedSignersFile = "${config.home.homeDirectory}/.ssh/allowed_signers";
          };
        };
        user = {
          email = "code@wimpress.io";
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

  sops = {
    secrets = {
      cg-repos = {
        path = "${config.home.homeDirectory}/.config/cg-repos";
        sopsFile = ../../../../secrets/cg-repos.yaml;
        mode = "0644";
      };
    };
  };
}
