# Fingerprint reader support via fprintd. Gated on the "fprintd" host tag.
# Hyprlock handles fingerprint auth over D-Bus directly, so fprintAuth is
# disabled on the hyprlock PAM service to prevent sensor conflicts.
{
  lib,
  noughtyLib,
  ...
}:
lib.mkIf (noughtyLib.hostHasTag "fprintd") {
  services.fprintd.enable = true;

  # Disable PAM fprintd module for services where fingerprint is unwanted.
  # When services.fprintd.enable = true, NixOS defaults fprintAuth = true
  # on every PAM service. We want fingerprint only via hyprlock's native
  # D-Bus integration, not via PAM.
  security.pam.services = {
    # Display manager: passphrase only (macOS-style behaviour).
    greetd.fprintAuth = false;
    login.fprintAuth = false;
    # Hyprlock uses D-Bus to talk to fprintd directly; if PAM also tries
    # to claim the sensor, the two fight and one fails.
    hyprlock.fprintAuth = false;
    # sudo and polkit: passphrase only.
    sudo.fprintAuth = false;
    polkit-1.fprintAuth = false;
  };

  # Restart fprintd after suspend to avoid stale device handles.
  # This is a known issue with some fingerprint readers (Goodix included).
  systemd.services.fprintd-resume = {
    description = "Restart fprintd after resume from suspend";
    before = [ "sleep.target" ];
    wantedBy = [ "sleep.target" ];
    unitConfig = {
      DefaultDependencies = "no";
      StopWhenUnneeded = true;
    };
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "/run/current-system/sw/bin/true";
      ExecStop = "/run/current-system/sw/bin/systemctl restart fprintd.service";
    };
  };
}
