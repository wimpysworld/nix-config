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
  hasAcceleration = builtins.hasAttr hostname accelerationMap;
  installOpenWebUI = if hostname == "revan" then true else false;
  sithLord =
    (lib.strings.toUpper (builtins.substring 0 1 hostname)) +
    (builtins.substring 1 (builtins.stringLength hostname) hostname);
  # Construct URLs for each host in accelerationMap
  baseUrls = lib.concatStringsSep ";" (map (host: "http://${host}:11434") (builtins.attrNames accelerationMap));
in
{
  environment.systemPackages = lib.mkIf hasAcceleration (with pkgs; [
    gollama
  ]);
  services = {
    ollama = {
      acceleration = lib.mkIf hasAcceleration accelerationMap.${hostname};
      enable = hasAcceleration;
      host = "0.0.0.0";
      loadModels = [
        "bge-reranker-v2-m3:latest"
        "codegemma:7b"
        "gemma2:9b"                     #4k context
        "llama3.2-vision:11b"
        "llama3.1:8b"                   #128k context
        "mistral-nemo:12b"              #128k context
        "nemotron-mini:4b"              #4k context
        "nomic-embed-text:latest"
        "qwen2.5-coder:14b"
      ];
    };
    open-webui = {
      enable = installOpenWebUI;
      environment = {
        CHUNK_SIZE = 1536;
        CHUNK_OVERLAP = 128;
        CONTENT_EXTRACTION_ENGINE = "tika";
        DATA_DIR = "/srv/open-webui";
        DEFAULT_MODELS = "llama3.1:8b";
        DEFAULT_USER_ROLE = "user";
        ENABLE_IMAGE_GENERATION = "true";
        ENABLE_RAG_WEB_SEARCH = "true";
        IMAGE_GENERATION_ENGINE = "openai";
        RAG_WEB_SEARCH_RESULT_COUNT = 5;
        RAG_WEB_SEARCH_CONCURRENT_REQUESTS = 2;
        ENABLE_RAG_LOCAL_WEB_FETCH = "true";
        ENABLE_SEARCH_QUERY = "true";
        ENABLE_SIGNUP = "true";
        ENABLE_LOGIN_FORM = "true";
        IMAGE_GENERATION_ENGINE = "openai";
        RAG_EMBEDDING_ENGINE = "ollama";
        RAG_EMBEDDING_MODEL = "nomic-embed-text:latest";
        RAG_WEB_SEARCH_ENGINE = "brave";
        RAG_RERANKING_MODEL = "bge-reranker-v2-m3:latest";
        RESET_CONFIG_ON_START = "true";
        TASK_MODEL = "gemma2:9b";
        WEBUI_NAME = "${sithLord} Chat";
        WEBUI_URL = if (config.services.tailscale.enable && config.services.caddy.enable) then
            "https://${hostname}.${tailNet}/"
          else
            "http://localhost:${toString config.services.open-webui.port}";
        OLLAMA_BASE_URLS = baseUrls;
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
    chromadb = {
      enable = installOpenWebUI;
      dbpath = "/srv/chromadb"
    };
    tika.enable = installOpenWebUI;
  };
  sops = {
    secrets = {
      open-webui-env = lib.mkIf installOpenWebUI {
        group = "root";
        mode = "0644";
        owner = "root";
        path = "/etc/open-webui/secrets.env";
        sopsFile = ../../../../secrets/open-webui.yaml;
      };
    };
  };
}
