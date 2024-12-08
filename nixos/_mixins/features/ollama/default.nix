{
  config,
  hostname,
  lib,
  pkgs,
  tailNet,
  ...
}:
let
  accelerationMap = {
    phasma = "rocm";
    vader = "cuda";
  };
  sithLord =
    (lib.strings.toUpper (builtins.substring 0 1 hostname)) +
    (builtins.substring 1 (builtins.stringLength hostname) hostname);
in
lib.mkIf (builtins.hasAttr hostname accelerationMap) {
  environment.systemPackages = with pkgs; [
    oterm
  ];
  services = {
    ollama = {
      acceleration = accelerationMap.${hostname};
      enable = true;
      loadModels = [
        "qwen2.5-coder:14b"
        "qwen2.5-coder:32b"
      ];
    };
    open-webui = {
      enable = true;
      environment = {
        WEBUI_NAME = "${sithLord} Chat";
        OLLAMA_API_BASE_URL = "http://${config.services.ollama.host}:${toString config.services.ollama.port}";
      };
      host = "0.0.0.0";
      openFirewall = true;
      port = 8088;
    };
  };
}
