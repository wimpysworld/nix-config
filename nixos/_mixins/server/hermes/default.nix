{
  config,
  inputs,
  lib,
  noughtyLib,
  ...
}:
let
  username = config.noughty.user.name;
  podmanEnabled = lib.attrByPath [
    "home-manager"
    "users"
    username
    "services"
    "podman"
    "enable"
  ] false config;
in
{
  imports = [
    inputs.hermes-agent.nixosModules.default
  ];

  config = lib.mkIf (noughtyLib.hostHasTag "hermes") {
    assertions = [
      {
        assertion = podmanEnabled;
        message = "Hermes requires Podman from home-manager/_mixins/development/virtualisation.";
      }
    ];

    virtualisation.docker.enable = lib.mkForce false;

    security.sudo.extraRules = [
      {
        users = [ username ];
        commands = [
          {
            command = "/run/current-system/sw/bin/podman";
            options = [ "NOPASSWD" ];
          }
        ];
      }
    ];

    services.hermes-agent = {
      enable = true;
      addToSystemPackages = true;

      container = {
        enable = true;
        backend = "podman";
        hostUsers = [ username ];
        extraOptions = [ "--network=host" ];
      };

      settings = {
        model = {
          default = "qwen3.5:9b";
          provider = "custom";
          base_url = "http://revan.drongo-gamma.ts.net:8080/v1";
        };

        fallback_model = {
          provider = "openai-codex";
          model = "gpt-5.4";
        };
      };
    };
  };
}
