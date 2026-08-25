set -euo pipefail

fail() {
  printf 'herdr-work-layout-test: %s\n' "$1" >&2
  exit 1
}

workspace_cwd="$TMPDIR/project"
fake_bin="$TMPDIR/fake-bin"
event_file="$TMPDIR/event.json"
context_file="$TMPDIR/context.json"
log_file="$TMPDIR/herdr.log"
expected_log="$TMPDIR/expected.log"

mkdir -p "$workspace_cwd" "$fake_bin"
install -Dm755 "$fakeHerdr" "$fake_bin/herdr"
patchShebangs "$fake_bin/herdr"

export FAKE_HERDR_LOG="$log_file"

write_invocation() {
  local with_worktree=$1
  local focused=$2

  jq -cn \
    --arg cwd "$workspace_cwd" \
    --argjson focused "$focused" \
    --argjson with_worktree "$with_worktree" '
      {
        event: "workspace_created",
        data: {
          type: "workspace_created",
          workspace: {
            workspace_id: "workspace-1",
            number: 1,
            label: "project",
            focused: $focused,
            pane_count: 1,
            tab_count: 1,
            active_tab_id: "tab-claude",
            agent_status: "idle"
          }
        }
      }
      | if $with_worktree then
          .data.workspace.worktree = {
            repo_key: "project",
            repo_name: "project",
            repo_root: $cwd,
            checkout_path: $cwd,
            is_linked_worktree: true
          }
        else . end
    ' >"$event_file"

  jq -cn \
    --arg cwd "$workspace_cwd" \
    --argjson with_worktree "$with_worktree" '
      {
        workspace_id: "workspace-1",
        workspace_label: "project",
        workspace_cwd: $cwd,
        tab_id: "tab-claude",
        tab_label: "1",
        focused_pane_id: "pane-claude",
        focused_pane_cwd: $cwd,
        focused_pane_status: "idle",
        invocation_source: "api",
        correlation_id: "workspace.created"
      }
      | if $with_worktree then
          .worktree = {
            repo_key: "project",
            repo_name: "project",
            repo_root: $cwd,
            checkout_path: $cwd,
            is_linked_worktree: true
          }
        else . end
    ' >"$context_file"
}

run_layout() {
  HERDR_ENV=1 \
    HERDR_BIN_PATH="$fake_bin/herdr" \
    HERDR_PLUGIN_EVENT=workspace.created \
    HERDR_PLUGIN_EVENT_JSON="$(<"$event_file")" \
    HERDR_PLUGIN_CONTEXT_JSON="$(<"$context_file")" \
    "$script"
}

{
  printf 'tab\trename\ttab-claude\tClaude\n'
  for label in Codex OpenCode Pi Git Code Linear GitHub Shell; do
    printf 'tab\tcreate\t--workspace\tworkspace-1\t--cwd\t%s\t--label\t%s\t--no-focus\n' \
      "$workspace_cwd" "$label"
  done
} >"$expected_log"

run_success_case() {
  local name=$1
  local with_worktree=$2
  local focused=$3

  write_invocation "$with_worktree" "$focused"
  : >"$log_file"
  run_layout >"$TMPDIR/success-$name.out"
  cmp "$expected_log" "$log_file"
}

run_success_case ordinary false true
run_success_case worktree true true
run_success_case background false false

: >"$log_file"
if HERDR_PLUGIN_EVENT=worktree.created \
  HERDR_PLUGIN_EVENT_JSON="$(<"$event_file")" \
  HERDR_PLUGIN_CONTEXT_JSON="$(<"$context_file")" \
  "$script" >"$TMPDIR/wrong-event.out" 2>&1; then
    fail "the wrong event case succeeded"
  fi
[[ ! -s $log_file ]] || fail "the wrong event case called Herdr"

write_invocation false true
jq '.workspace_id = "workspace-2"' "$context_file" >"$TMPDIR/mismatched-context.json"
mv "$TMPDIR/mismatched-context.json" "$context_file"
: >"$log_file"
if output=$(run_layout 2>&1); then
  fail "the mismatched context case succeeded"
fi
[[ ! -s $log_file ]] || fail "the mismatched context case called Herdr"
[[ $output == *"does not match the event context"* ]] || fail "the context error was not useful"

write_invocation false true
: >"$log_file"
export FAKE_HERDR_FAIL_COMMAND="tab create --workspace workspace-1 --cwd $workspace_cwd --label Git --no-focus"
if output=$(run_layout 2>&1); then
  fail "the Herdr failure case succeeded"
fi
unset FAKE_HERDR_FAIL_COMMAND
[[ $output == *"workspace workspace-1"* ]] || fail "the Herdr failure error omitted the workspace ID"
[[ $output == *"partial workspace was preserved"* ]] || fail "the Herdr failure error omitted recovery guidance"
[[ $(wc -l <"$log_file") -eq 5 ]] || fail "the Herdr failure case continued after the failed call"

write_invocation false true
: >"$log_file"
export FAKE_HERDR_MALFORMED_COMMAND="tab create --workspace workspace-1 --cwd $workspace_cwd --label Code --no-focus"
if output=$(run_layout 2>&1); then
  fail "the malformed response case succeeded"
fi
unset FAKE_HERDR_MALFORMED_COMMAND
[[ $output == *"creating the Code tab returned an invalid Herdr response"* ]] || fail "the malformed response error was not useful"
[[ $(wc -l <"$log_file") -eq 6 ]] || fail "the malformed response case continued after the invalid response"

touch "$out"
