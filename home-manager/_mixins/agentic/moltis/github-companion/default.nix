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
  updateModel ? sweepModel,
  sweepModel ? codeModel,
  codeModel,
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
  communityAutoMergeEnabled ? true,
  communityAutoMergeMaxLines ? 150,
  communityAutoMergeMaxFiles ? 5,
  communityAutoMergeExcludedRepos ? [ "wimpysworld/nix-config" ],
  pollIntervalMinutes ? 30,
  maxTasksPerSlot ? (if agentName == "traya" then 3 else 2),
  maxTasksPerDay ? 48,
  dailyImplementationsCap ? (if agentName == "traya" then 0 else 8),
  operatorDigestEnabled ? true,
  securityPatchReleaseExtraRepos ? [ ],
  securityPatchReleaseCooldownSecs ? 7200,
  linearClientIdPath ? "",
  linearClientSecretPath ? "",
  linearLabelApiKeyPath ? "",
  linearTokenCacheDir ? "",
  linearTeamKey ? "WW",
  ghApiSafe ? null,
  shadowEvalEnabled ? (agentName == "skrye" || agentName == "zannah"),
  shadowModel ? (
    if agentName == "skrye" then
      "inkling-2-mini"
    else if agentName == "zannah" then
      "qwen3.8-27b"
    else
      ""
  ),
  shadowApiUrl ? "http://127.0.0.1:8080/v1/chat/completions",
  shadowSummaryPath ? "",
  shadowTimeoutSecs ? 120,
}:
let
  companionSrc = lib.fileset.toSource {
    root = ./..;
    fileset = lib.fileset.unions [
      ./companion.py
      ./linear_sync.py
      ./shadow_eval.py
      ../linear-token/linear_token.py
    ];
  };
in
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
    linearSyncScript = ./linear_sync.py;
    shadowEvalScript = ./shadow_eval.py;
    inherit
      companionSrc
      agentName
      agentDisplayName
      updateModel
      sweepModel
      codeModel
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
      communityAutoMergeEnabled
      communityAutoMergeMaxLines
      communityAutoMergeMaxFiles
      communityAutoMergeExcludedRepos
      pollIntervalMinutes
      maxTasksPerSlot
      maxTasksPerDay
      dailyImplementationsCap
      operatorDigestEnabled
      securityPatchReleaseExtraRepos
      securityPatchReleaseCooldownSecs
      linearClientIdPath
      linearClientSecretPath
      linearLabelApiKeyPath
      linearTokenCacheDir
      linearTeamKey
      ghApiSafe
      shadowEvalEnabled
      shadowModel
      shadowApiUrl
      shadowSummaryPath
      shadowTimeoutSecs
      ;
  };
  text = ''
    export MOLTIS_GITHUB_COMPANION_AGENT_NAME=${lib.escapeShellArg agentName}
    export MOLTIS_GITHUB_COMPANION_AGENT_DISPLAY_NAME=${lib.escapeShellArg agentDisplayName}
    export MOLTIS_GITHUB_COMPANION_UPDATE_MODEL=${lib.escapeShellArg updateModel}
    export MOLTIS_GITHUB_COMPANION_SWEEP_MODEL=${lib.escapeShellArg sweepModel}
    export MOLTIS_GITHUB_COMPANION_CODE_MODEL=${lib.escapeShellArg codeModel}
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
    export MOLTIS_GITHUB_COMPANION_COMMUNITY_AUTO_MERGE_ENABLED=${lib.escapeShellArg (lib.boolToString communityAutoMergeEnabled)}
    export MOLTIS_GITHUB_COMPANION_COMMUNITY_AUTO_MERGE_MAX_LINES=${lib.escapeShellArg (toString communityAutoMergeMaxLines)}
    export MOLTIS_GITHUB_COMPANION_COMMUNITY_AUTO_MERGE_MAX_FILES=${lib.escapeShellArg (toString communityAutoMergeMaxFiles)}
    export MOLTIS_GITHUB_COMPANION_COMMUNITY_AUTO_MERGE_EXCLUDED_REPOS=${lib.escapeShellArg (lib.concatStringsSep "," communityAutoMergeExcludedRepos)}
    export MOLTIS_GITHUB_COMPANION_POLL_INTERVAL_MINUTES=${lib.escapeShellArg (toString pollIntervalMinutes)}
    export MOLTIS_GITHUB_COMPANION_MAX_TASKS_PER_SLOT=${lib.escapeShellArg (toString maxTasksPerSlot)}
    export MOLTIS_GITHUB_COMPANION_MAX_TASKS_PER_DAY=${lib.escapeShellArg (toString maxTasksPerDay)}
    export MOLTIS_GITHUB_COMPANION_DAILY_IMPLEMENTATIONS_CAP=${lib.escapeShellArg (toString dailyImplementationsCap)}
    export MOLTIS_GITHUB_COMPANION_DIGEST_ENABLED=${lib.escapeShellArg (lib.boolToString operatorDigestEnabled)}
    export MOLTIS_GITHUB_COMPANION_SECURITY_RELEASE_EXTRA_REPOS=${lib.escapeShellArg (lib.concatStringsSep "," securityPatchReleaseExtraRepos)}
    export MOLTIS_GITHUB_COMPANION_SECURITY_RELEASE_COOLDOWN_SECS=${lib.escapeShellArg (toString securityPatchReleaseCooldownSecs)}
    export MOLTIS_GITHUB_COMPANION_LINEAR_CLIENT_ID_PATH=${lib.escapeShellArg linearClientIdPath}
    export MOLTIS_GITHUB_COMPANION_LINEAR_CLIENT_SECRET_PATH=${lib.escapeShellArg linearClientSecretPath}
    export MOLTIS_GITHUB_COMPANION_LINEAR_LABEL_API_KEY_PATH=${lib.escapeShellArg linearLabelApiKeyPath}
    export MOLTIS_GITHUB_COMPANION_LINEAR_TOKEN_CACHE_DIR=${lib.escapeShellArg linearTokenCacheDir}
    export MOLTIS_GITHUB_COMPANION_LINEAR_TEAM_KEY=${lib.escapeShellArg linearTeamKey}
    export MOLTIS_GITHUB_COMPANION_SHADOW_EVAL_ENABLED=${lib.escapeShellArg (lib.boolToString shadowEvalEnabled)}
    export MOLTIS_GITHUB_COMPANION_SHADOW_MODEL=${lib.escapeShellArg shadowModel}
    export MOLTIS_GITHUB_COMPANION_SHADOW_API_URL=${lib.escapeShellArg shadowApiUrl}
    export MOLTIS_GITHUB_COMPANION_SHADOW_SUMMARY_PATH=${lib.escapeShellArg shadowSummaryPath}
    export MOLTIS_GITHUB_COMPANION_SHADOW_TIMEOUT_SECS=${lib.escapeShellArg (toString shadowTimeoutSecs)}
    exec python3 ${companionSrc}/github-companion/companion.py "$@"
  '';
}
