{
  config,
  lib,
  pkgs,
  ...
}:
let
  mcpSopsFile = ../../../../secrets/mcp.yaml;
  # Import shared MCP server definitions.
  mcpServerDefs = import ./servers.nix { inherit config pkgs; };
  inherit (mcpServerDefs) opencodeServers;

  # Secrets that aren't tied to any active MCP server but still need to be
  # decrypted to disk and exported into the shell. SEMGREP_APP_TOKEN is used
  # by the security scanner skill, not by any MCP server. The disabled
  # *_API_KEY entries belong to firecrawl and mcp-google-cse and stay
  # declared so flipping their global `enabled` flag back on does not need
  # a sops-rekey round-trip.
  additionalSecrets = [
    "FIRECRAWL_API_KEY"
    "GOOGLE_CSE_API_KEY"
    "GOOGLE_CSE_ENGINE_ID"
    "SEMGREP_APP_TOKEN"
  ];

  # Union of canonical-derived secrets (currently CONTEXT7_API_KEY) and the
  # hand-maintained additional set. Drives both `sops.secrets` declarations
  # and the shell init exports below.
  allSecrets = lib.unique (mcpServerDefs.requiredSecrets ++ additionalSecrets);

  fishExport =
    var: "set -gx ${var} (cat ${config.sops.secrets.${var}.path} 2>/dev/null; or echo \"\")";
  bashExport =
    var: "export ${var}=$(cat ${config.sops.secrets.${var}.path} 2>/dev/null || echo \"\")";

  # Keys we expect to see in Zed's `context_servers` table after activation.
  # Computed from the renderer output so it stays in sync with `servers.nix`.
  zedManagedContextServers = lib.attrNames (
    mcpServerDefs.zedContextServers // mcpServerDefs.zedExtensionDisables
  );
  zedSettingsPath = "${config.xdg.configHome}/zed/settings.json";
in
{
  programs = {
    fish = {
      shellInit = ''
        # Export MCP secrets from sops
        ${lib.concatMapStringsSep "\n" fishExport allSecrets}
      '';
    };
    bash = {
      initExtra = ''
        # Export MCP secrets from sops
        ${lib.concatMapStringsSep "\n" bashExport allSecrets}
      '';
    };
    opencode = lib.mkIf config.programs.opencode.enable {
      enableMcpIntegration = true;
      settings = {
        mcp = opencodeServers;
      };
    };
    zed-editor = lib.mkIf config.programs.zed-editor.enable {
      extensions = mcpServerDefs.zedExtensions;
      userSettings = {
        # Stdio/HTTP context servers plus disabled-extension stubs share
        # one `context_servers` table. The stubs let Zed's agent panel
        # toggle extension-mode servers without a Home Manager rebuild.
        context_servers = mcpServerDefs.zedContextServers // mcpServerDefs.zedExtensionDisables;
      };
    };
  };

  # Purge stale MCP entries from Zed's `context_servers` table before the
  # upstream `zedSettingsActivation` hook merges Nix-generated settings into
  # the on-disk file. Home Manager merges with `jq '$dynamic * $static'`,
  # which is a deep merge: top-level keys on disk that the Nix config no
  # longer emits are kept forever. For `context_servers` specifically that
  # leaks removed or globally-disabled servers (e.g. `jina`) into Zed.
  #
  # The renderer is the source of truth, so anything not in
  # `zedManagedContextServers` gets dropped. Other top-level settings keys
  # are left untouched - users may legitimately set those via Zed's UI.
  home.activation = lib.mkIf config.programs.zed-editor.enable {
    mcpZedContextServersPurge =
      lib.hm.dag.entryBetween [ "zedSettingsActivation" ] [ "linkGeneration" ]
        ''
          settings_path=${lib.escapeShellArg zedSettingsPath}
          managed=${lib.escapeShellArg (builtins.toJSON zedManagedContextServers)}
          jq=${lib.getExe pkgs.jq}

          # First-run on a fresh machine: nothing to purge yet.
          if [[ ! -f "$settings_path" ]]; then
            exit 0
          fi

          # Skip silently if the file is unreadable as JSON (corrupt or empty).
          if ! "$jq" -e . "$settings_path" >/dev/null 2>&1; then
            exit 0
          fi

          tmp="$(${pkgs.coreutils}/bin/mktemp "$settings_path.XXXXXX")"
          if "$jq" --argjson managed "$managed" '
            if has("context_servers") then
              .context_servers |= with_entries(select(.key as $k | $managed | index($k)))
            else . end
          ' "$settings_path" > "$tmp"; then
            ${pkgs.coreutils}/bin/mv "$tmp" "$settings_path"
          else
            ${pkgs.coreutils}/bin/rm -f "$tmp"
          fi
        '';
  };
  sops = {
    secrets = lib.genAttrs allSecrets (_: {
      sopsFile = mcpSopsFile;
    });
    # MCP servers - used by other agents
    templates."mcp-config.json" = {
      content = builtins.toJSON { mcpServers = mcpServerDefs.claudeServers; };
      path = "${config.xdg.configHome}/mcp/mcp.json";
    };
  };
}
