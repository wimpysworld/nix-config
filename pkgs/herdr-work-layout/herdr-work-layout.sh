die() {
  printf 'herdr-work-layout: %s\n' "$1" >&2
  exit 1
}

if [[ ${HERDR_PLUGIN_EVENT:-} != "workspace.created" ]]; then
  die "expected HERDR_PLUGIN_EVENT=workspace.created"
fi

event_json=${HERDR_PLUGIN_EVENT_JSON:-}
context_json=${HERDR_PLUGIN_CONTEXT_JSON:-}

if ! jq -e '
  type == "object"
  and .event == "workspace_created"
  and (.data | type == "object")
  and .data.type == "workspace_created"
  and (.data.workspace | type == "object")
  and (.data.workspace.workspace_id | type == "string" and length > 0)
  and (.data.workspace.number | type == "number" and . >= 0 and floor == .)
  and (.data.workspace.label | type == "string" and length > 0)
  and (.data.workspace.focused | type == "boolean")
  and .data.workspace.pane_count == 1
  and .data.workspace.tab_count == 1
  and (.data.workspace.active_tab_id | type == "string" and length > 0)
  and (.data.workspace.agent_status | type == "string" and length > 0)
  and (
    .data.workspace.worktree == null
    or (
      (.data.workspace.worktree | type == "object")
      and (.data.workspace.worktree.repo_key | type == "string" and length > 0)
      and (.data.workspace.worktree.repo_name | type == "string" and length > 0)
      and (.data.workspace.worktree.repo_root | type == "string" and length > 0)
      and (.data.workspace.worktree.checkout_path | type == "string" and length > 0)
      and (.data.workspace.worktree.is_linked_worktree | type == "boolean")
    )
  )
' >/dev/null 2>&1 <<<"$event_json"; then
  die "HERDR_PLUGIN_EVENT_JSON is not a valid Herdr v0.8.2 workspace.created event"
fi

workspace_id=$(jq -er '.data.workspace.workspace_id' <<<"$event_json")
claude_tab_id=$(jq -er '.data.workspace.active_tab_id' <<<"$event_json")

fail_workspace() {
  printf 'herdr-work-layout: workspace %s: %s. The partial workspace was preserved. Run herdr workspace focus %s and finish the layout manually.\n' \
    "$workspace_id" "$1" "$workspace_id" >&2
  exit 1
}

if ! jq -e \
  --arg workspace_id "$workspace_id" \
  --arg tab_id "$claude_tab_id" \
  --argjson worktree "$(jq -c '.data.workspace.worktree // null' <<<"$event_json")" '
    type == "object"
    and .workspace_id == $workspace_id
    and .tab_id == $tab_id
    and (.workspace_cwd | type == "string" and length > 0)
    and (.focused_pane_id | type == "string" and length > 0)
    and .focused_pane_cwd == .workspace_cwd
    and (.worktree // null) == $worktree
  ' >/dev/null 2>&1 <<<"$context_json"; then
  fail_workspace "HERDR_PLUGIN_CONTEXT_JSON does not match the event context"
fi

workspace_cwd=$(jq -er '.workspace_cwd' <<<"$context_json")
claude_pane_id=$(jq -er '.focused_pane_id' <<<"$context_json")

if [[ ${HERDR_ENV:-} != "1" ]]; then
  fail_workspace "expected HERDR_ENV=1"
fi

herdr_bin=${HERDR_BIN_PATH:-}
if [[ -z $herdr_bin || ! -x $herdr_bin ]]; then
  fail_workspace "HERDR_BIN_PATH does not name an executable Herdr binary"
fi

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
      type == "object"
      and (.result | type == "object")
      and .result.type == "tab_info"
      and .result.tab.workspace_id == $workspace_id
      and .result.tab.tab_id == $tab_id
      and (.result.tab.number | type == "number" and . >= 1 and floor == .)
      and .result.tab.label == $label
      and (.result.tab.focused | type == "boolean")
      and (.result.tab.pane_count | type == "number" and . >= 1 and floor == .)
      and (.result.tab.agent_status | type == "string" and length > 0)
    ' >/dev/null 2>&1 <<<"$response"; then
    fail_workspace "$operation returned an invalid Herdr response"
  fi
}

validate_focused_tab_info() {
  local response=$1
  local tab_id=$2
  local label=$3
  local operation=$4

  validate_tab_info "$response" "$tab_id" "$label" "$operation"
  if ! jq -e '.result.tab.focused == true' >/dev/null 2>&1 <<<"$response"; then
    fail_workspace "$operation returned an invalid Herdr response"
  fi
}

validate_ok() {
  local response=$1
  local operation=$2

  if ! jq -e '
    type == "object"
    and (.result | type == "object")
    and .result.type == "ok"
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
    --cwd "$workspace_cwd" \
    --label "$label" \
    --no-focus

  if ! jq -e \
    --arg workspace_id "$workspace_id" \
    --arg label "$label" '
      type == "object"
      and (.result | type == "object")
      and .result.type == "tab_created"
      and .result.tab.workspace_id == $workspace_id
      and .result.tab.label == $label
      and (.result.tab.tab_id | type == "string" and length > 0)
      and (.result.tab.number | type == "number" and . >= 1 and floor == .)
      and .result.tab.focused == false
      and .result.tab.pane_count == 1
      and (.result.tab.agent_status | type == "string" and length > 0)
      and (.result.root_pane | type == "object")
      and .result.root_pane.workspace_id == $workspace_id
      and .result.root_pane.tab_id == .result.tab.tab_id
      and (.result.root_pane.pane_id | type == "string" and length > 0)
      and (.result.root_pane.terminal_id | type == "string" and length > 0)
      and .result.root_pane.focused == false
      and (.result.root_pane.agent_status | type == "string" and length > 0)
      and (.result.root_pane.revision | type == "number" and . >= 0 and floor == .)
    ' >/dev/null 2>&1 <<<"$response"; then
    fail_workspace "creating the $label tab returned an invalid Herdr response"
  fi

  created_tab_id=$(jq -er '.result.tab.tab_id' <<<"$response")
  created_pane_id=$(jq -er '.result.root_pane.pane_id' <<<"$response")
}

herdr_call response "renaming the initial tab" tab rename "$claude_tab_id" Claude
validate_tab_info "$response" "$claude_tab_id" Claude "renaming the initial tab"

declare -A tab_ids=( [Claude]="$claude_tab_id" )
declare -A pane_ids=( [Claude]="$claude_pane_id" )

for label in Codex OpenCode Pi Git Code Linear GitHub Shell; do
  create_tab "$label"
  tab_ids["$label"]=$created_tab_id
  pane_ids["$label"]=$created_pane_id
done

worktree_checkout=$(jq -r '.data.workspace.worktree.checkout_path // empty' <<<"$event_json")
if [[ -z $worktree_checkout ]]; then
  printf 'herdr-work-layout: prepared shell tabs in workspace %s.\n' "$workspace_id"
  exit 0
fi

home_directory=${HOME:-}
if [[ -z $home_directory ]]; then
  fail_workspace "HOME is not set"
fi

chainguard_root_path="$home_directory/Chainguard"
if ! chainguard_root=$(realpath -e -- "$chainguard_root_path" 2>/dev/null) \
  || [[ ! -d $chainguard_root ]]; then
  printf 'herdr-work-layout: prepared shell tabs in workspace %s.\n' "$workspace_id"
  exit 0
fi

if ! checkout_path=$(realpath -e -- "$worktree_checkout" 2>/dev/null) \
  || [[ ! -d $checkout_path ]] \
  || [[ $checkout_path != "$chainguard_root/"* ]]; then
  printf 'herdr-work-layout: prepared shell tabs in workspace %s.\n' "$workspace_id"
  exit 0
fi

run_in_pane() {
  local pane_id=$1
  local command_text=$2
  local response

  herdr_call response "running '$command_text' in pane $pane_id" \
    pane run "$pane_id" "$command_text"
}

close_created_tab() {
  local label=$1
  local tab_id=${tab_ids[$label]}
  local response

  herdr_call response "closing the $label tab" tab close "$tab_id"
  validate_ok "$response" "closing the $label tab"
}

run_in_pane "${pane_ids[Claude]}" "claude-fenced"
run_in_pane "${pane_ids[Codex]}" "codex-fenced"
run_in_pane "${pane_ids[Git]}" "lg"
run_in_pane "${pane_ids[Code]}" "fresh ."

close_created_tab OpenCode
close_created_tab Pi

herdr_call response "focusing the Claude tab" tab focus "${tab_ids[Claude]}"
validate_focused_tab_info "$response" "${tab_ids[Claude]}" Claude "focusing the Claude tab"

printf 'herdr-work-layout: prepared Chainguard worktree workspace %s and focused tab %s.\n' \
  "$workspace_id" "${tab_ids[Claude]}"
