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
    revan = "cuda";
    vader = "cuda";
  };
  hasAcceleration = builtins.hasAttr hostname accelerationMap;
  installOpenWebUI = if hostname == "revan" then true else false;
  sithLord =
    (lib.strings.toUpper (builtins.substring 0 1 hostname)) +
    (builtins.substring 1 (builtins.stringLength hostname) hostname);
  # Construct URLs for each host in accelerationMap, excluding revan
  baseUrls = lib.concatStringsSep ";" (map (host: "http://${host}:11434")
    (lib.filter (host: host != "revan") (builtins.attrNames accelerationMap)));
in
{
  environment = {
    shellAliases = lib.mkMerge [
      (lib.optionalAttrs hasAcceleration {
        ollama-log = "journalctl _SYSTEMD_UNIT=ollama.service";
      })
      (lib.optionalAttrs installOpenWebUI {
        open-webui-log = "journalctl _SYSTEMD_UNIT=open-webui.service";
      })
    ];
    systemPackages = lib.mkIf hasAcceleration (with pkgs; [
      unstable.gollama
    ]);
  };
  services = {
    ollama = {
      acceleration = lib.mkIf hasAcceleration accelerationMap.${hostname};
      enable = hasAcceleration;
      host = if hostname == "revan" then "127.0.0.1" else "0.0.0.0";
      package = pkgs.unstable.ollama;
      loadModels = if hostname == "revan" then [
        #"deepseek-r1:32b"               #128k
        "gemma3:12b"                     #128k (vision)
        #"qwq"                    
        #"mistral-small3.1"              #128k (vision)
        "mxbai-embed-large:335m"
        "nomic-embed-text:latest"
      ] else [
        "codestral:22b"                 #32K  (code)
        "deepseek-r1:14b"               #128k (code)
        "mistral-small3.1"              #128k (vision)
        "mxbai-embed-large:335m"
        "nomic-embed-text:latest"
        "phi4:14b"                      #16K
        "qwen2.5-coder:14b"             #128k (code)
      ];
    };
    open-webui = {
      enable = installOpenWebUI;
      environment = {
        ALLOW_RESET = "true";
        CHUNK_SIZE = "1536";
        CHUNK_OVERLAP = "128";
        #CONTENT_EXTRACTION_ENGINE = "tika";
        DEFAULT_MODELS = if hostname == "revan" then "gemma3:12b" else "mistral-small3.1";
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
        MODEL_FILTER_LIST = if hostname == "revan" then "gemma3:12b" else "codestral:22b;deepseek-r1:14b;mistral-small3.1;phi4:14b;qwen2.5-coder:14b";
        OLLAMA_BASE_URLS = baseUrls;
        RAG_EMBEDDING_BATCH_SIZE = "16";
        RAG_EMBEDDING_ENGINE = "ollama";
        RAG_EMBEDDING_MODEL = "mxbai-embed-large:335m";
        # https://github.com/open-webui/open-webui/issues/7333#issuecomment-2512287381
        RAG_OLLAMA_BASE_URL = "http://config.services.ollama.host}:${toString config.services.ollama.port}";
        RAG_TEXT_SPLITTER = "token";
        RAG_WEB_SEARCH_ENGINE = "brave";
        RAG_WEB_SEARCH_RESULT_COUNT = "5";
        RAG_WEB_SEARCH_CONCURRENT_REQUESTS = "2";
        RESET_CONFIG_ON_START = "true";
        TASK_MODEL = if hostname == "revan" then "gemma3:12b" else "mistral-small3.1";
        TIKA_SERVER_URL = "http://${config.services.tika.listenAddress}:${toString config.services.tika.port}";
        USER_AGENT = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) OpenWebUI/${pkgs.open-webui.version} Chrome/131.0.0.0 Safari/537.36";
        WEBUI_NAME = "${sithLord} Chat";
        WEBUI_URL = if (config.services.tailscale.enable && config.services.caddy.enable) then
            "https://${hostname}.${tailNet}/"
          else
            "http://localhost:${toString config.services.open-webui.port}";
      };
      environmentFile = config.sops.secrets.open-webui-env.path;
      host = "127.0.0.1";
      port = 8088;
    };
    caddy = lib.mkIf config.services.caddy.enable {
      virtualHosts."${hostname}.${tailNet}" = lib.mkIf config.services.tailscale.enable {
        extraConfig = ''
            reverse_proxy ${config.services.open-webui.host}:${toString config.services.open-webui.port}
          '';
      };
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
