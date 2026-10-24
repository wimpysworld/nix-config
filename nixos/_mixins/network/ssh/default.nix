{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;
  # Don't open the firewall for SSH on laptops; Tailscale will handle it.
  openSSHFirewall = if (!host.is.iso && host.is.laptop) then false else true;
in
{
  environment = lib.mkIf (!host.is.iso) {
    # Workstations use the Home Manager gpg-agent as their only SSH agent.
    # greetd sources /etc/profile, so this gives the compositor and the apps
    # that it starts the gpg-agent socket for the default GNUPGHOME. A
    # forwarded or inherited agent is kept.
    extraInit = lib.mkIf host.is.workstation ''
      if [ -z "$SSH_AUTH_SOCK" ] && [ -n "$XDG_RUNTIME_DIR" ]; then
        export SSH_AUTH_SOCK="$XDG_RUNTIME_DIR/gnupg/S.gpg-agent.ssh"
      fi
    '';
    systemPackages = with pkgs; [
      alacritty.terminfo
      contour.terminfo
      foot.terminfo
      ghostty.terminfo
      kitty.terminfo
      rio.terminfo
      rxvt-unicode-unwrapped.terminfo
      st.terminfo
      yaft.terminfo
      wezterm.terminfo
      mtm.terminfo
      tmux.terminfo
      ssh-to-age
    ];
  };
  programs = {
    # Workstations use the Home Manager gpg-agent instead. Other hosts keep
    # the OpenSSH agent unless a keyring manages keys.
    ssh.startAgent = lib.mkDefault (
      !host.is.workstation && !config.services.gnome.gnome-keyring.enable
    );
  };
  services = {
    openssh = {
      enable = true;
      openFirewall = openSSHFirewall;
      settings = {
        PasswordAuthentication = false;
        PermitRootLogin = lib.mkIf host.is.server "prohibit-password";
      };
    };
    sshguard = {
      enable = !host.is.iso;
      whitelist = [
        "10.10.10.0/24"
        "10.10.30.0/24"
        "10.10.40.0/24"
        "10.10.50.0/24"
        "62.31.16.153/29"
        "80.209.186.64/28"
      ];
    };
  };
}
