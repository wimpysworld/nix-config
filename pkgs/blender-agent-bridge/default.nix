{
  lib,
  fetchFromGitHub,
  python3Packages,
}:

python3Packages.buildPythonApplication (finalAttrs: {
  pname = "blender-agent-bridge";
  version = "0.5.6";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "CallMeJones";
    repo = "blender-agent-bridge";
    rev = "8ef8fc8e0c8220dc812427f9ab89a4634b36cd78";
    hash = "sha256-5/33dOD0qv5QnPgtsOXgXzw0MrDO2i0iyaSwLzZQ1oc=";
  };

  build-system = with python3Packages; [
    setuptools
    wheel
  ];

  postInstall = ''
    mkdir -p "$out/share/blender-agent-bridge"
    cp -r addon/claude_blender "$out/share/blender-agent-bridge/claude_blender"
  '';

  pythonImportsCheck = [ "claude_blender.mcp_runtime.server" ];

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    export BLENDER_BRIDGE_EXECUTABLE="$out/bin/blender-bridge"
    "$BLENDER_BRIDGE_EXECUTABLE" --help
    python -m unittest tests.unit.test_package_metadata tests.unit.test_mcp_stdio -v
    runHook postInstallCheck
  '';

  meta = {
    description = "Blender extension and stdio MCP server for external agents";
    homepage = "https://github.com/CallMeJones/blender-agent-bridge";
    changelog = "https://github.com/CallMeJones/blender-agent-bridge/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.gpl3Plus;
    mainProgram = "blender-bridge";
    platforms = lib.platforms.unix;
  };
})
