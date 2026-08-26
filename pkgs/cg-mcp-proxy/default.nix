{
  chainctl,
  lib,
  python3,
  writeShellApplication,
}:
# A stdio MCP server that forwards to a Chainguard MCP server over HTTP, so
# every coding agent reaches those servers from one definition. It asks chainctl
# for the audience token and replaces the token before it expires, which is what
# an off-the-shelf proxy cannot do: mcp-proxy reads its Authorization header once
# at start, and its only dynamic option is a grant these servers do not offer.
writeShellApplication {
  name = "cg-mcp-proxy";

  runtimeInputs = [
    chainctl
    python3
  ];

  # The path is interpolated straight into the string rather than passed through
  # lib.escapeShellArg. escapeShellArg coerces a path with toString, which drops
  # the string context, and Nix then warns that the derivation carries no store
  # reference to the script. A store path holds no shell metacharacters, so the
  # quotes alone are enough.
  text = ''
    exec python3 "${./cg-mcp-proxy.py}" "$@"
  '';

  meta = {
    description = "stdio MCP bridge to Chainguard MCP servers, with chainctl tokens";
    mainProgram = "cg-mcp-proxy";
    platforms = lib.platforms.unix;
  };
}
