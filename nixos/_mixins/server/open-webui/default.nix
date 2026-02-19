{
  config,
  lib,
  noughtyLib,
  pkgs,
  ...
}:
let
  cfg = config.noughty.host;
  hostName = cfg.name;
  isInferenceServer = cfg.is.server && noughtyLib.hostHasTag "inference";

  # Pull model information from the ollama service configuration.
  defaultModel =
    let
      loaded = config.services.ollama.loadModels;
    in
    if loaded != [ ] then builtins.head loaded else "";

  embeddingModel = "nomic-embed-text:latest";
  taskModel = "qwen3:4b";

  # Build the model filter list from ollama's loaded models, excluding
  # embedding models (they have parameters like :278m, :335m in their names).
  modelFilterList =
    let
      loaded = config.services.ollama.loadModels;
      isEmbedding =
        m:
        lib.hasPrefix "nomic-embed" m
        || lib.hasPrefix "granite-embedding" m
        || lib.hasPrefix "mxbai-embed" m;
      generalModels = builtins.filter (m: !isEmbedding m) loaded;
    in
    lib.concatStringsSep ";" generalModels;
in
lib.mkIf isInferenceServer {
  environment.shellAliases.open-webui-log = "journalctl _SYSTEMD_UNIT=open-webui.service";
  services = {
    open-webui = {
      enable = true;
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
    tika.enable = true;
  };
  sops.secrets.open-webui-env = {
    group = "root";
    mode = "0644";
    owner = "root";
    path = "/etc/open-webui/secrets.env";
    sopsFile = ../../../../secrets/open-webui.yaml;
  };
}
