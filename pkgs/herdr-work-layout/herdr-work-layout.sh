die() {
  printf 'herdr-work-layout: %s\n' "$1" >&2
  exit 1
}

if [[ ${HERDR_PLUGIN_EVENT:-} != "worktree.created" ]]; then
  die "expected HERDR_PLUGIN_EVENT=worktree.created"
fi

event_json=${HERDR_PLUGIN_EVENT_JSON:-}
context_json=${HERDR_PLUGIN_CONTEXT_JSON:-}

if ! jq -e '
  type == "object"
  and .event == "worktree_created"
  and (.data | type == "object")
  and .data.type == "worktree_created"
  and (.data.workspace | type == "object")
  and (.data.workspace.workspace_id | type == "string" and length > 0)
  and (.data.workspace.number | type == "number" and . >= 0 and floor == .)
  and (.data.workspace.label | type == "string" and length > 0)
  and (.data.workspace.focused | type == "boolean")
  and (.data.workspace.pane_count | type == "number" and . >= 0 and floor == .)
  and (.data.workspace.tab_count | type == "number" and . >= 0 and floor == .)
  and (.data.workspace.active_tab_id | type == "string" and length > 0)
  and (.data.workspace.agent_status | type == "string" and length > 0)
  and (.data.workspace.worktree | type == "object")
  and (.data.workspace.worktree.repo_key | type == "string" and length > 0)
  and (.data.workspace.worktree.repo_name | type == "string" and length > 0)
  and (.data.workspace.worktree.repo_root | type == "string" and length > 0)
  and (.data.workspace.worktree.checkout_path | type == "string" and length > 0)
  and (.data.workspace.worktree.is_linked_worktree | type == "boolean")
  and (.data.worktree | type == "object")
  and (.data.worktree.path | type == "string" and length > 0)
  and (
    .data.worktree.branch == null
    or (.data.worktree.branch | type == "string" and length > 0)
  )
  and (.data.worktree.is_bare | type == "boolean")
  and (.data.worktree.is_detached | type == "boolean")
  and (.data.worktree.is_prunable | type == "boolean")
  and (.data.worktree.is_linked_worktree | type == "boolean")
  and (.data.worktree.open_workspace_id | type == "string" and length > 0)
  and (.data.worktree.label | type == "string" and length > 0)
  and .data.workspace.worktree.checkout_path == .data.worktree.path
  and .data.worktree.open_workspace_id == .data.workspace.workspace_id
' >/dev/null 2>&1 <<<"$event_json"; then
  die "HERDR_PLUGIN_EVENT_JSON is not a valid Herdr v0.8.2 worktree.created event"
fi

workspace_id=$(jq -er '.data.workspace.workspace_id' <<<"$event_json")
claude_tab_id=$(jq -er '.data.workspace.active_tab_id' <<<"$event_json")
event_worktree_path=$(jq -er '.data.worktree.path' <<<"$event_json")

fail_workspace() {
  printf 'herdr-work-layout: workspace %s: %s. The partial workspace was preserved. Run herdr workspace focus %s and finish the layout manually.\n' \
    "$workspace_id" "$1" "$workspace_id" >&2
  exit 1
}

if ! jq -e \
  --arg workspace_id "$workspace_id" \
  --arg tab_id "$claude_tab_id" \
  --arg worktree_path "$event_worktree_path" '
    type == "object"
    and .workspace_id == $workspace_id
    and .tab_id == $tab_id
    and (.focused_pane_id | type == "string" and length > 0)
    and (.worktree | type == "object")
    and .worktree.checkout_path == $worktree_path
  ' >/dev/null 2>&1 <<<"$context_json"; then
  fail_workspace "HERDR_PLUGIN_CONTEXT_JSON does not match the event context"
fi

claude_pane_id=$(jq -er '.focused_pane_id' <<<"$context_json")

home_directory=${HOME:-}
if [[ -z $home_directory ]]; then
  fail_workspace "HOME is not set"
fi
chainguard_root_path="$home_directory/Chainguard"
if ! chainguard_root=$(realpath -e -- "$chainguard_root_path" 2>/dev/null); then
  exit 0
fi
if ! worktree_path=$(realpath -e -- "$event_worktree_path" 2>/dev/null); then
  fail_workspace "cannot resolve worktree path '$event_worktree_path'"
fi

case "$worktree_path" in
  "$chainguard_root"/*) ;;
  *) exit 0 ;;
esac

if ! branch_name=$(jq -er '
  .data.worktree.branch
  | select(type == "string" and length > 0)
' <<<"$event_json"); then
  fail_workspace "worktree event does not contain a branch name"
fi

if [[ ${HERDR_ENV:-} != "1" ]]; then
  fail_workspace "expected HERDR_ENV=1"
fi

herdr_bin=${HERDR_BIN_PATH:-}
if [[ -z $herdr_bin || ! -x $herdr_bin ]]; then
  fail_workspace "HERDR_BIN_PATH does not name an executable Herdr binary"
fi

for command_name in claude-fenced codex-fenced lazygit; do
  if ! command -v "$command_name" >/dev/null 2>&1; then
    fail_workspace "required command '$command_name' is not available in PATH"
  fi
done

herdr_call() {
  local output_variable=$1
  local operation=$2
  local output
  shift 2

  if ! output=$("$herdr_bin" "$@"); then
    fail_workspace "$operation failed"
  fi
  printf -v "$output_variable" '%s' "$output"
}

validate_tab_info() {
  local response=$1
  local tab_id=$2
  local label=$3
  local operation=$4

  if ! jq -e \
    --arg workspace_id "$workspace_id" \
    --arg tab_id "$tab_id" \
    --arg label "$label" '
      .result.type == "tab_info"
      and .result.tab.workspace_id == $workspace_id
      and .result.tab.tab_id == $tab_id
      and .result.tab.label == $label
    ' >/dev/null 2>&1 <<<"$response"; then
    fail_workspace "$operation returned an invalid Herdr response"
  fi
}

validate_workspace_info() {
  local response=$1
  local operation=$2

  if ! jq -e \
    --arg workspace_id "$workspace_id" \
    --arg label "$branch_name" '
      .result.type == "workspace_info"
      and .result.workspace.workspace_id == $workspace_id
      and .result.workspace.label == $label
    ' >/dev/null 2>&1 <<<"$response"; then
    fail_workspace "$operation returned an invalid Herdr response"
  fi
}

create_tab() {
  local label=$1
  local response

  herdr_call response "creating the $label tab" \
    tab create \
    --workspace "$workspace_id" \
    --cwd "$worktree_path" \
    --label "$label" \
    --no-focus

  if ! jq -e \
    --arg workspace_id "$workspace_id" \
    --arg label "$label" '
      .result.type == "tab_created"
      and .result.tab.workspace_id == $workspace_id
      and .result.tab.label == $label
      and (.result.tab.tab_id | type == "string" and length > 0)
      and .result.root_pane.workspace_id == $workspace_id
      and .result.root_pane.tab_id == .result.tab.tab_id
      and (.result.root_pane.pane_id | type == "string" and length > 0)
    ' >/dev/null 2>&1 <<<"$response"; then
    fail_workspace "creating the $label tab returned an invalid Herdr response"
  fi

  created_tab_id=$(jq -er '.result.tab.tab_id' <<<"$response")
  created_pane_id=$(jq -er '.result.root_pane.pane_id' <<<"$response")
}

herdr_call response "renaming the workspace" workspace rename "$workspace_id" "$branch_name"
validate_workspace_info "$response" "renaming the workspace"

herdr_call response "renaming the initial tab" tab rename "$claude_tab_id" Claude
validate_tab_info "$response" "$claude_tab_id" Claude "renaming the initial tab"

create_tab Codex
codex_tab_id=$created_tab_id
codex_pane_id=$created_pane_id

create_tab Git
git_tab_id=$created_tab_id
git_pane_id=$created_pane_id

create_tab Shell
shell_tab_id=$created_tab_id
shell_pane_id=$created_pane_id

herdr_call response "starting claude-fenced" pane run "$claude_pane_id" claude-fenced
herdr_call response "starting codex-fenced" pane run "$codex_pane_id" codex-fenced
herdr_call response "starting lazygit" pane run "$git_pane_id" lazygit

herdr_call response "focusing the Claude tab" tab focus "$claude_tab_id"
validate_tab_info "$response" "$claude_tab_id" Claude "focusing the Claude tab"

printf 'herdr-work-layout: prepared workspace %s with tabs %s, %s, %s, and %s; Shell pane %s is idle.\n' \
  "$workspace_id" "$claude_tab_id" "$codex_tab_id" "$git_tab_id" "$shell_tab_id" "$shell_pane_id"
