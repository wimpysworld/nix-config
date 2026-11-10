{
  lib,
  python3Packages,
}:

python3Packages.buildPythonApplication (finalAttrs: {
  pname = "twelvetake-reaper-mcp";
  version = "1.11.0";
  pyproject = true;

  src = python3Packages.fetchPypi {
    pname = "twelvetake_reaper_mcp";
    inherit (finalAttrs) version;
    hash = "sha256-r8vo2zxoLiQoY7Zqw/OoUmnLLqBjr3T2q4HIEElcoyE=";
  };

  build-system = [ python3Packages.hatchling ];
  dependencies = [ python3Packages.mcp ];

  postInstall = ''
    install -Dm644 reaper_mcp_bridge.lua \
      "$out/share/twelvetake-reaper-mcp/reaper_mcp_bridge.lua"
    install -Dm644 twelvetake_mcp_analyzer.jsfx \
      "$out/share/twelvetake-reaper-mcp/twelvetake_mcp_analyzer.jsfx"
  '';

  pythonImportsCheck = [ "reaper_mcp_server" ];

  meta = {
    description = "REAPER bridge and stdio MCP server for music production";
    homepage = "https://twelvetake.com/tools/reaper-mcp/";
    license = lib.licenses.mit;
    mainProgram = "twelvetake-reaper-mcp";
    platforms = lib.platforms.linux;
  };
})
