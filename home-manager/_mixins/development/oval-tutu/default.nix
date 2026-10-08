# Oval-Tutu - credentials for Oval-Tutu development environments.
#
# Each key in envKeys is exported under its own name. Secret names carry an
# OVAL_TUTU_ prefix because sops secret names are global and other Home
# Manager modules declare secrets such as TELEGRAM_BOT_TOKEN from other sops
# files. The telegram_bot key holds the bot name and is exported as
# TELEGRAM_BOT_NAME. The rendered oval-tutu.env dotenv file is loaded by a
# project .envrc with dotenv_if_exists.
{
  config,
  lib,
  noughtyLib,
  ...
}:
let
  inherit (config.noughty) host;
  ovalTutuSopsFile = ../../../../secrets/oval-tutu.yaml;
  envKeys = [
    "TELEGRAM_BOT_TOKEN"
    "CLOUDFLARE_ACCOUNT_ID"
    "CLOUDFLARE_API_TOKEN"
    "CLOUDFLARE_KV_NAMESPACE"
    "FIVEHORIZONS_RELAY_WORKER"
    "FIVEHORIZONS_RELAY_URL"
    "FIVEHORIZONS_BUILD_KEY"
    "OVALTUTUBOT_ADMIN_KEY"
    "ANDROID_DEBUG_SIGNINGKEY_BASE64"
    "ANDROID_DEBUG_ALIAS"
    "ANDROID_DEBUG_KEYSTORE_PASSWORD"
    "ANDROID_DEBUG_KEY_PASSWORD"
    "ANDROID_RELEASE_SIGNINGKEY_BASE64"
    "ANDROID_RELEASE_ALIAS"
    "ANDROID_RELEASE_KEYSTORE_PASSWORD"
    "ANDROID_RELEASE_KEY_PASSWORD"
  ];
  secretName = key: "OVAL_TUTU_${key}";
in
lib.mkIf
  (host.is.workstation && noughtyLib.userHasTag "developer" && noughtyLib.isUser [ "martin" ])
  {
    sops.secrets = {
      telegram_bot = {
        sopsFile = ovalTutuSopsFile;
        mode = "0400";
      };
    }
    // lib.listToAttrs (
      map (key: {
        name = secretName key;
        value = {
          sopsFile = ovalTutuSopsFile;
          inherit key;
          mode = "0400";
        };
      }) envKeys
    );

    sops.templates."oval-tutu.env" = {
      content = ''
        TELEGRAM_BOT_NAME=${config.sops.placeholder.telegram_bot}
      ''
      + lib.concatMapStrings (key: "${key}=${config.sops.placeholder.${secretName key}}\n") envKeys;
      mode = "0400";
    };
  }
