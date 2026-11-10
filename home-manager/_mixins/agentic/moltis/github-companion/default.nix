{
  pkgs,
  lib,
  agentName,
  agentDisplayName ? (
    if agentName == "zannah" then
      "Zannah"
    else if agentName == "traya" then
      "Traya"
    else
      "Skrye"
  ),
  mainModel,
  reviewModel ? mainModel,
  scheduleDow ? (
    if agentName == "zannah" then
      4
    else if agentName == "traya" then
      0
    else
      2
  ),
  scheduleDayName ? (
    if agentName == "zannah" then
      "Thursday"
    else if agentName == "traya" then
      "disabled"
    else
      "Tuesday"
  ),
  selfUserId ? "@${agentName}:matrix.wimpys.world",
  roomId ? "!the-cauldron:matrix.wimpys.world",
  homeserverUrl ? "https://matrix.wimpys.world",
  passwordPath,
  telegramBotTokenPath ? "",
  telegramAllowedUsersPath ? "",
  telegramApiBaseUrl ? "https://api.telegram.org",
  telegramApiUrl ? telegramApiBaseUrl,
  dataDir,
  stateDir,
  rpcUrl ? "https://127.0.0.1:13131/api/rpc",
  ghApiSafe ? null,
}:
pkgs.writeShellApplication {
  name = "moltis-github-companion";
  runtimeInputs = [
    pkgs.python3
    pkgs.git
    pkgs.gh
  ]
  ++ lib.optional (ghApiSafe != null) ghApiSafe;
  derivationArgs.passthru = {
    script = ./companion.py;
    inherit
      agentName
      agentDisplayName
      mainModel
      reviewModel
      scheduleDow
      scheduleDayName
      selfUserId
      roomId
      homeserverUrl
      passwordPath
      telegramBotTokenPath
      telegramAllowedUsersPath
      telegramApiBaseUrl
      telegramApiUrl
      dataDir
      stateDir
      rpcUrl
      ghApiSafe
      ;
  };
  text = ''
    export MOLTIS_GITHUB_COMPANION_AGENT_NAME=${lib.escapeShellArg agentName}
    export MOLTIS_GITHUB_COMPANION_AGENT_DISPLAY_NAME=${lib.escapeShellArg agentDisplayName}
    export MOLTIS_GITHUB_COMPANION_MAIN_MODEL=${lib.escapeShellArg mainModel}
    export MOLTIS_GITHUB_COMPANION_REVIEW_MODEL=${lib.escapeShellArg reviewModel}
    export MOLTIS_GITHUB_COMPANION_SCHEDULE_DOW=${lib.escapeShellArg (toString scheduleDow)}
    export MOLTIS_GITHUB_COMPANION_SCHEDULE_DAY_NAME=${lib.escapeShellArg scheduleDayName}
    export MOLTIS_GITHUB_COMPANION_MATRIX_SELF_USER_ID=${lib.escapeShellArg selfUserId}
    export MOLTIS_GITHUB_COMPANION_MATRIX_ROOM_ID=${lib.escapeShellArg roomId}
    export MOLTIS_GITHUB_COMPANION_MATRIX_HOMESERVER_URL=${lib.escapeShellArg homeserverUrl}
    export MOLTIS_GITHUB_COMPANION_MATRIX_PASSWORD_PATH=${lib.escapeShellArg passwordPath}
    export MOLTIS_GITHUB_COMPANION_TELEGRAM_BOT_TOKEN_PATH=${lib.escapeShellArg telegramBotTokenPath}
    export MOLTIS_GITHUB_COMPANION_TELEGRAM_ALLOWED_USERS_PATH=${lib.escapeShellArg telegramAllowedUsersPath}
    export MOLTIS_GITHUB_COMPANION_TELEGRAM_API_URL=${lib.escapeShellArg telegramApiUrl}
    export MOLTIS_GITHUB_COMPANION_DATA_DIR=${lib.escapeShellArg dataDir}
    export MOLTIS_GITHUB_COMPANION_STATE_DIR=${lib.escapeShellArg stateDir}
    export MOLTIS_GITHUB_COMPANION_RPC_URL=${lib.escapeShellArg rpcUrl}
    exec python3 ${./companion.py} "$@"
  '';
}
