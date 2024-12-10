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
    phasma = "cuda";
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
        "codegemma:7b-instruct-v1.1-q8_0"
        "gemma2:9b-instruct-q8_0"
        "gemma2:27b-instruct-q4_0"
        "llama3.2-vision:11b-instruct-q8_0"
        "llama3.1:8b-instruct-fp16"
        "mistral-nemo:12b-instruct-2407-q8_0"
        "qwen2.5-coder:14b-instruct-q8_0"
      ];
    };
    open-webui = {
      enable = true;
      environment = {
        DEFAULT_MODELS = "gemma2:27b-instruct-q4_0";
        DEFAULT_USER_ROLE = "user";
        ENABLE_IMAGE_GENERATION = "true";
        ENABLE_RAG_WEB_SEARCH = "true";
        ENABLE_SEARCH_QUERY = "true";
        IMAGE_GENERATION_ENGINE = "openai";
        #RAG_WEB_SEARCH_ENGINE = "kagi";
        WEBUI_NAME = "${sithLord} Chat";
        WEBUI_URL = if (config.services.tailscale.enable && config.services.caddy.enable) then
            "https://${hostname}.${tailNet}/"
          else
            "http://localhost:${toString config.services.open-webui.port}";
        OLLAMA_BASE_URL = "http://${config.services.ollama.host}:${toString config.services.ollama.port}";
      };
      environmentFile = config.sops.secrets.open-webui-env.path;
      host = "127.0.0.1";
      port = 8088;
    };
    caddy = lib.mkIf config.services.caddy.enable {
      virtualHosts."${hostname}.${tailNet}" = lib.mkIf config.services.tailscale.enable {
        extraConfig = ''
            reverse_proxy localhost:${toString config.services.open-webui.port}
          '';
      };
    };
  };
  sops = {
    secrets = {
      open-webui-env = {
        group = "root";
        mode = "0644";
        owner = "root";
        path = "/etc/open-webui/secrets.env";
        sopsFile = ../../../../secrets/open-webui.yaml;
      };
    };
  };
}
