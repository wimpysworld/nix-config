{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;
  # The Home Manager socket unit already derives the path from GNUPGHOME, with
  # `%t` for the runtime directory. environment.d does not expand unit
  # specifiers, so it gets the same path through XDG_RUNTIME_DIR.
  sshSocket = config.systemd.user.sockets.gpg-agent-ssh.Socket.ListenStream;
in
{
  programs = {
    gpg = {
      enable = true;
    };
  };

  services = {
    gpg-agent = {
      enable = true;
      enableSshSupport = true;
      pinentry.package =
        if host.is.linux && host.is.workstation then pkgs.pinentry-gnome3 else pkgs.pinentry-curses;
    };
  };

  # gpg-agent is the only SSH agent. The shell integration sets
  # SSH_AUTH_SOCK in shells. This sets it in the systemd user manager, so the
  # session, D-Bus-activated apps and user services use the same agent.
  systemd.user.sessionVariables = lib.mkIf host.is.linux {
    SSH_AUTH_SOCK = lib.mkDefault (lib.replaceStrings [ "%t" ] [ "\${XDG_RUNTIME_DIR}" ] sshSocket);
  };

  # On generic Linux, the distribution user units for gcr and OpenSSH start
  # their own agents and run `systemctl --user set-environment SSH_AUTH_SOCK`,
  # which overrides environment.d. A user-level mask stops them, whatever the
  # distribution enables globally or orders after gpg-agent. The Home Manager
  # gpg-agent units replace the distribution units of the same name.
  xdg.configFile = lib.mkIf config.targets.genericLinux.enable (
    lib.genAttrs
      (map (unit: "systemd/user/${unit}") [
        "gcr-ssh-agent.service"
        "gcr-ssh-agent.socket"
        "ssh-agent.service"
        "ssh-agent.socket"
      ])
      (_: {
        source = config.lib.file.mkOutOfStoreSymlink "/dev/null";
      })
  );
}
