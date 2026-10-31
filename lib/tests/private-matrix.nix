# Run by checks.x86_64-linux.private-matrix. Check deployment wiring and API side effects.
{
  lib,
  pkgs,
  nixosConfigurations,
  homeConfigurations,
}:
let
  inherit (nixosConfigurations) malak;
  inherit (malak) config;
  disabled =
    (malak.extendModules {
      modules = [ { services.privateMatrix.enable = lib.mkForce false; } ];
    }).config;
  service = config.systemd.services.private-matrix-bootstrap;
  registrationSecret = "MATRIX_REGISTRATION_SHARED_SECRET";
  checkHome =
    host:
    let
      home = homeConfigurations."martin@${host}".config;
      agent = if host == "momin" then "traya" else host;
      matrix = home.agentic.moltis.matrix;
      channel = home.agentic.moltis.settings.channels.matrix."matrix-${agent}";
      hooks = home.agentic.moltis.settings.hooks.hooks;
      secret = home.sops.secrets.MATRIX_PASSWORD;
    in
    assert matrix.enable;
    assert channel.room_allowlist == [ matrix.roomId ];
    assert !channel.reply_to_message;
    assert channel.operators == [ "@martin:matrix.wimpys.world" ];
    assert
      channel.user_allowlist == [
        "@martin:matrix.wimpys.world"
        "@skrye:matrix.wimpys.world"
        "@zannah:matrix.wimpys.world"
        "@traya:matrix.wimpys.world"
      ];
    assert builtins.length hooks == 1;
    assert (builtins.head hooks).name == "matrix-council-context";
    assert (builtins.head hooks).events == [ "BeforeLLMCall" ];
    assert secret.sopsFile == config.sops.secrets.${secret.key}.sopsFile;
    assert !(home.sops.secrets ? MATRIX_REGISTRATION_SHARED_SECRET);
    channel.device_id;
  devices = map checkHome [
    "skrye"
    "zannah"
    "momin"
  ];
in
assert config.services.privateMatrix.enable;
assert builtins.all (a: a.assertion) config.assertions;
assert !(disabled.systemd.services ? private-matrix-bootstrap);
assert !(disabled.sops.secrets ? MATRIX_REGISTRATION_SHARED_SECRET);
assert lib.elem "tuwunel.service" service.requires;
assert lib.elem "tuwunel.service" service.after;
assert lib.elem "tuwunel.service" service.partOf;
assert
  config.systemd.services.tuwunel.serviceConfig.LoadCredential == [
    "${registrationSecret}:${config.sops.secrets.${registrationSecret}.path}"
  ];
assert builtins.length (lib.unique devices) == builtins.length devices;
pkgs.runCommand "private-matrix"
  {
    bootstrapTests = malak.pkgs.private-matrix-bootstrap.tests;
  }
  ''
    test -e "$bootstrapTests"
    ${lib.getExe config.services.caddy.package} adapt --adapter caddyfile \
      --config ${config.services.caddy.configFile} > /dev/null
    touch "$out"
  ''
