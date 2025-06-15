{
  config,
  lib,
  pkgs,
  username,
  ...
}:
let
  inherit (pkgs.stdenv) isDarwin isLinux;
  installFor = [ "martin" "martin.wimpress" ];
  keysSopsFile = ../../../../secrets/keys.yaml;
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
  allEd25519SkSecrets = lib.foldl lib.recursiveUpdate {} (
    map (baseName: mkSshKeySecrets "id_ed25519_sk" baseName) ed25519SkKeyIdentifiers
  );
  # Make with: pamu2fcfg -n
  u2f_28L     = "TBfRqRfHADrZSgh4nOAwbCOgsbc0QTVwa0duBV3Qaz2ROuQ86QUR+70Hytzjicj88GhA0RRh2jNNe0ktKgzmXQ==,aUjvFdpwTbafll6K28EwSvLj7C+7XY/La+m3YXIeMTqRKu9+RarhGaOPQdXxfwwoa+ynjkZXtmVCkr5Nb+WPdQ==,es256,+presence";
  u2f_45L     = "fitUdpvbJ6SMWMkojEDpOnUTdCXFt/qlQpZzXBpdQHzC/qPdKPBjo+HGmcLfIO+yGRsefmIb2jS4Gn3mDJ0CeA==,AKu1ho3I+PfNtB52egDBx/VAwrD5EMNl6zyTGgcvSHpp8AOWHwrbdfroIaoTGZNMZVWI4QvF8+HrTBv48lb7sA==,es256,+presence";
  u2f_bane    = "1CGgpplq9YQv7JB9Au0Zusc6GWCuXatBpXeBgrFjEbCcnNd6Opi6yH4ybf/nbJzbBrC16/I/P259cMN1l4FNTw==,XEDLhzRweaSG6HQqXZJmkJlQQwsjMTXzgyjHOz5haNUKM2HjCn5eB/LOgN8oGdIUMlpD44TXF0OEgBa02KeD9w==,es256,+presence";
  u2f_keyring = "VyWPeIGWO3PA7ZeIxl1osBlEwv01mQUeYZfoed3qk+EdZThOAUIdIt+Ac+rTwix01x/B8QyErgJjjTKvMVDTbg==,BGGhoF38N4J0VNh05lRl3ho/4kAK+vEolNROoWadRG8hO6rtF7ROIMnTiojndKtXdzNfT6ML+ZJUWuIjiOZ01w==,es256,+presence";
  u2f_phasma  = "U8Za14UahAnDSSwA6y2EJpDjIZP+0IliX9Ta//89oCvaNPGlVaxTCQY6VPShTNV41agGH+O+AuOfOcV6pIS9Wg==,2o6OE9jB4E62FGcCmAPDXaY4FyT5uSNBVW9LydetbJFgZem9GZtJ1tnXt2FJm/sHgmg8BBqIY+QIf/r+5oFXMw==,es256,+presence";
  u2f_vader   = "G4S+zVnfPIpcnShvEuLYazwAS8XhX8DRyZZBX2OdV3K+7RVbr4UG+TqmmT3kEgC0XgTpKpN2cM/t4CpFDUE9Ig==,xxXHLkGtoMUAEbyu7/TMxmPGjuqISDVT1ldSy7qoWppWzgNlyvZZiu5bST7Llf3sHLDsT/agFbqzuf4HcVJZcw==,es256,+presence";
in
lib.mkIf (lib.elem username installFor) {
  home.packages = with pkgs; [
    yubikey-manager
  ] ++ lib.optionals isLinux [
    pam_u2f
    pamtester
  ] ++ lib.optionals isDarwin [
    openssh # needed for FIDO2 support
  ];
  programs = {
    fish = {
      shellAliases = lib.mkIf isDarwin {
        ssh-agent-start = "eval (${pkgs.openssh}/bin/ssh-agent -c)";
        ssh-agent-stop = "${pkgs.openssh}/bin/ssh-agent -k";
      };
    };
    gpg = lib.mkIf isLinux {
      # Prevent the PCSC-Lite conflicting with gpg-agent
      # https://wiki.nixos.org/wiki/Yubikey#Smartcard_mode
      scdaemonSettings = {
        disable-ccid = true;
      };
    };
    ssh = lib.mkIf isDarwin {
      addKeysToAgent = "yes";
      enable = true;
      includes = [
        "${config.home.homeDirectory}/.ssh/local_config"
      ];
      package = pkgs.openssh;
    };
  };

  sops = {
    secrets = allEd25519SkSecrets;
  };

  xdg = lib.mkIf isLinux {
    configFile."Yubico/u2f_keys".text = ''
      ${username}:${u2f_28L}:${u2f_45L}:${u2f_bane}:${u2f_keyring}:${u2f_phasma}:${u2f_vader}
    '';
  };
}
