rec {
  piMcpAdapterRevision = "1c7a84d489c18c69fde3d6a6503cd051133dd9a9";
  # Verify Agent, SubagentWorkflow, and native header compatibility on updates.
  # The provider router uses separate model and thinking fields for Agent,
  # and model and effort fields for workflow children.
  piSubagentsVersion = "0.22.0";
  piMcpAdapterSource = "git:github.com/nicobailon/pi-mcp-adapter@${piMcpAdapterRevision}";
  piSubagentsSource = "npm:@tintinweb/pi-subagents@${piSubagentsVersion}";

  piSubagentsConfig = {
    backgroundByDefault = true;
    maxConcurrent = 12;
    maxConcurrentForeground = 12;
    maxSubagentDepth = 1;
    defaultMaxTurns = 50;
    graceTurns = 5;
    defaultJoinMode = "async";
    disableDefaultAgents = true;
    packageAgents = false;
    packageWorkflows = false;
    fallbackSubagent = "none";
    strictAgentFiles = true;
    rememberAgents = true;
    outputTranscript = true;
    workflowsEnabled = true;
    # Use the routed tool entry points, not independent launch paths.
    agentMentions = "off";
    schedulingEnabled = false;
    # Upstream 0.20.0 force-removes worktrees after preservation errors.
    # The router rejects isolation requests rather than silently downgrading them.
    worktreeIsolation = false;
  };
}
