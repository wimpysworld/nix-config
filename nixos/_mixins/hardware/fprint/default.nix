# Fingerprint reader support via fprintd. Gated on the "fprintd" host tag.
# A fingerprint unlocks the Veila lock screen only. Veila verifies
# fingerprints over the fprintd D-Bus API, in parallel with its password
# field. Every PAM service, including sudo, polkit, run0, su, passwd and the
# greeter, uses the password. The greeter must use the password because the
# password unlocks GNOME Keyring.
{
  config,
  lib,
  noughtyLib,
  ...
}:
let
  hasFprintd = noughtyLib.hostHasTag "fprintd";
in
{
  # NixOS defaults fprintAuth to services.fprintd.enable on every PAM service.
  # This submodule extension lowers that default to false for every service,
  # including services that NixOS adds later. A plain definition elsewhere
  # still wins over mkDefault, so the assertion below catches it.
  options.security.pam.services = lib.mkOption {
    type = lib.types.attrsOf (
      lib.types.submodule {
        config.fprintAuth = lib.mkIf hasFprintd (lib.mkDefault false);
      }
    );
  };

  config = lib.mkIf hasFprintd {
    services.fprintd.enable = true;

    # Veila claims the sensor itself, so PAM must never also claim it on veila.
    security.pam.services.veila.fprintAuth = lib.mkForce false;

    assertions = [
      (
        let
          fingerprintServices = lib.attrNames (
            lib.filterAttrs (_: service: service.fprintAuth) config.security.pam.services
          );
        in
        {
          assertion = fingerprintServices == [ ];
          message = "Fingerprint hosts must not use pam_fprintd. Set fprintAuth = false on these PAM services: ${lib.concatStringsSep ", " fingerprintServices}.";
        }
      )
    ];

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
  };
}
