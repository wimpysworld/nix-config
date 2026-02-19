{
  config,
  lib,
  noughtyLib,
  pkgs,
  ...
}:
let
  hostName = config.noughty.host.name;
  accelerationMap = {
    maul = "cuda";
    phasma = "cuda";
    vader = "cuda";
  };
  hasAcceleration = builtins.hasAttr hostName accelerationMap;
  installOpenWebUI = if hostName == "maul" then true else false;

  defaultModel = if hostName == "maul" then "gemma3:27b-it-qat" else "gemma3:12b-it-qat"; # 128k (multi-modal)
  embeddingModel = "nomic-embed-text:latest"; # 2K   (embedding)
  taskModel = "qwen3:4b"; # 40k  (task)
  embeddingModels = [
    embeddingModel
    "granite-embedding:278m" # 512  (embedding)
    "mxbai-embed-large:335m" # 512  (embedding)
  ];
  generalModels = [
    defaultModel
    taskModel
    "granite3.3:8b" # 128k (instruct)
    "phi4:14b" # 32k  (general)
    "phi4-mini:3.8b" # 128k (task/reasoning)
    "qwen2.5-coder:7b" # 32k  (code reasoning)
  ]
  ++ lib.optionals (hostName == "maul") [
    "cogito:32b" # 128k (stem)
    "qwen2.5-coder:32b" # 32k  (code reasoning)
    "qwen3:32b" # 40k  (general)
  ]
  ++ lib.optionals (hostName == "vader" || hostName == "phasma") [
    "cogito:14b" # 128k (stem)
    "qwen2.5-coder:14b" # 32k  (code reasoning)
    "qwen3:14b" # 40k  (cot)
  ];
  # Transform defaultModels into a ; separated string for Open WebUI filter
  modelFilterList = lib.concatStringsSep ";" (generalModels);
in
{
  environment = {
    shellAliases = lib.mkMerge [
      (lib.optionalAttrs config.services.ollama.enable {
        ollama-log = "journalctl _SYSTEMD_UNIT=ollama.service";
      })
      (lib.optionalAttrs config.services.open-webui.enable {
        open-webui-log = "journalctl _SYSTEMD_UNIT=open-webui.service";
      })
    ];
    systemPackages = lib.mkIf config.services.ollama.enable (
      with pkgs;
      [
        gollama
      ]
    );
  };
  services = {
    ollama = {
      acceleration = lib.mkIf hasAcceleration accelerationMap.${hostName};
      enable = hasAcceleration;
      host = if hostName == "maul" then "0.0.0.0" else "127.0.0.1";
      loadModels = generalModels ++ lib.optionals (config.services.ollama.enable) embeddingModels;
    };
    open-webui = {
      enable = installOpenWebUI;
      environment = {
        ALLOW_RESET = "true";
        CHUNK_SIZE = "1536";
        CHUNK_OVERLAP = "128";
        #CONTENT_EXTRACTION_ENGINE = "tika";
        DEFAULT_MODELS = defaultModel;
        DEFAULT_USER_ROLE = "user";
        ENABLE_EVALUATION_ARENA_MODELS = "false";
        ENABLE_IMAGE_GENERATION = "true";
        ENABLE_LOGIN_FORM = "true";
        ENABLE_MODEL_FILTER = "true";
        #ENABLE_RAG_HYBRID_SEARCH = "false";
        ENABLE_RAG_WEB_SEARCH = "true";
        ENABLE_RAG_LOCAL_WEB_FETCH = "true";
        ENABLE_SEARCH_QUERY = "true";
        ENABLE_SIGNUP = "true";
        IMAGE_GENERATION_ENGINE = "openai";
        MODEL_FILTER_LIST = modelFilterList;
        OLLAMA_BASE_URLS = "http://127.0.0.1:${toString config.services.ollama.port}";
        RAG_EMBEDDING_BATCH_SIZE = "16";
        RAG_EMBEDDING_ENGINE = "ollama";
        RAG_EMBEDDING_MODEL = embeddingModel;
        # https://github.com/open-webui/open-webui/issues/7333#issuecomment-2512287381
        RAG_OLLAMA_BASE_URL = "http://127.0.0.1:${toString config.services.ollama.port}";
        RAG_TEXT_SPLITTER = "token";
        RAG_WEB_SEARCH_ENGINE = "brave";
        RAG_WEB_SEARCH_RESULT_COUNT = "10";
        RAG_WEB_SEARCH_CONCURRENT_REQUESTS = "2";
        RESET_CONFIG_ON_START = "true";
        TASK_MODEL = taskModel;
        TIKA_SERVER_URL = "http://${config.services.tika.listenAddress}:${toString config.services.tika.port}";
        USER_AGENT = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) OpenWebUI/${pkgs.open-webui.version} Chrome/131.0.0.0 Safari/537.36";
        WEBUI_NAME = "${noughtyLib.hostNameCapitalised} Chat";
        WEBUI_URL =
          if (config.services.tailscale.enable && config.services.caddy.enable) then
            "https://${hostName}.${config.noughty.network.tailNet}/"
          else
            "http://localhost:${toString config.services.open-webui.port}";
      };
      environmentFile = config.sops.secrets.open-webui-env.path;
      host = "127.0.0.1";
      port = 8088;
    };
    caddy = lib.mkIf config.services.caddy.enable {
      virtualHosts."${hostName}.${config.noughty.network.tailNet}" =
        lib.mkIf config.services.tailscale.enable
          {
            extraConfig = ''
              reverse_proxy ${config.services.open-webui.host}:${toString config.services.open-webui.port}
            '';
          };
    };
    tika.enable = config.services.open-webui.enable;
  };
  sops = {
    secrets = {
      open-webui-env = lib.mkIf config.services.open-webui.enable {
        group = "root";
        mode = "0644";
        owner = "root";
        path = "/etc/open-webui/secrets.env";
        sopsFile = ../../../../secrets/open-webui.yaml;
      };
    };
  };
}
