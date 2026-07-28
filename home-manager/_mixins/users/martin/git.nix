{
  config,
  lib,
  noughtyLib,
  ...
}:
lib.mkIf (noughtyLib.isUser [ "martin" ]) {
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
  };

  programs = {
    git = {
      # Work repositories are clones nested under ~/Chainguard and are signed
      # with Sigstore rather than the personal SSH key. The `gitdir:` condition
      # matches one path component before `**`, so it captures the nested
      # clones at any depth and skips the ~/Chainguard/.git of cg-env itself.
      includes = [
        {
          condition = "gitdir:~/Chainguard/*/";
          contents = {
            commit.gpgsign = true;
            gitsign.connectorID = "https://accounts.google.com";
            gpg = {
              format = "x509";
              # Home Manager defaults the x509 signer to gpgsm, so name gitsign.
              x509.program = "gitsign";
            };
            tag.gpgsign = true;
            user = {
              email = "martin.wimpress@chainguard.dev";
              name = "Martin Wimpress";
            };
          };
        }
      ];
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
        path = "${config.xdg.configHome}/cg-repos";
        sopsFile = ../../../../secrets/cg-repos.yaml;
        mode = "0644";
      };
    };
  };
}
