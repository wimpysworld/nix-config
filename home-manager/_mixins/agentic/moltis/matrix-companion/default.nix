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
  selfUserId ? "@${agentName}:matrix.wimpys.world",
  roomId ? "!the-cauldron:matrix.wimpys.world",
  homeserverUrl ? "https://matrix.wimpys.world",
  passwordPath,
  dataDir,
  stateDir,
  rpcUrl ? "https://127.0.0.1:13131/api/rpc",
}:
pkgs.writeShellApplication {
  name = "moltis-matrix-companion";
  runtimeInputs = [ pkgs.python3 ];
  derivationArgs.passthru = {
    script = ./companion.py;
    inherit
      agentName
      agentDisplayName
      mainModel
      selfUserId
      roomId
      homeserverUrl
      passwordPath
      dataDir
      stateDir
      rpcUrl
      ;
  };
  text = ''
    export MOLTIS_COMPANION_AGENT_NAME=${lib.escapeShellArg agentName}
    export MOLTIS_COMPANION_AGENT_DISPLAY_NAME=${lib.escapeShellArg agentDisplayName}
    export MOLTIS_COMPANION_MAIN_MODEL=${lib.escapeShellArg mainModel}
    export MOLTIS_COMPANION_SELF_USER_ID=${lib.escapeShellArg selfUserId}
    export MOLTIS_COMPANION_ROOM_ID=${lib.escapeShellArg roomId}
    export MOLTIS_COMPANION_HOMESERVER_URL=${lib.escapeShellArg homeserverUrl}
    export MOLTIS_COMPANION_PASSWORD_PATH=${lib.escapeShellArg passwordPath}
    export MOLTIS_COMPANION_DATA_DIR=${lib.escapeShellArg dataDir}
    export MOLTIS_COMPANION_STATE_DIR=${lib.escapeShellArg stateDir}
    export MOLTIS_COMPANION_RPC_URL=${lib.escapeShellArg rpcUrl}
    exec python3 ${./companion.py} "$@"
  '';
}
