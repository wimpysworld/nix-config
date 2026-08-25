set -euo pipefail

fail() {
  printf 'herdr-work-layout-test: %s\n' "$1" >&2
  exit 1
}

test_home="$TMPDIR/home"
chainguard_root="$test_home/Chainguard"
inside_path="$chainguard_root/project/feature"
outside_path="$test_home/Outside/project"
prefix_path="$test_home/Chainguard-old/project"
escape_path="$chainguard_root/escape"
missing_path="$chainguard_root/missing"
fake_bin="$TMPDIR/fake-bin"
event_file="$TMPDIR/event.json"
context_file="$TMPDIR/context.json"
log_file="$TMPDIR/herdr.log"
work_log="$TMPDIR/work.log"
codex_pane_id=opaque-pane-q19
git_pane_id=opaque-pane-w46
code_pane_id=opaque-pane-f38
opencode_tab_id=opaque-tab-m44
pi_tab_id=opaque-tab-z08

mkdir -p "$inside_path" "$outside_path" "$prefix_path" "$fake_bin"
ln -s "$outside_path" "$escape_path"
install -Dm755 "$fakeHerdr" "$fake_bin/herdr"
patchShebangs "$fake_bin/herdr"

export HOME="$test_home"
export FAKE_HERDR_LOG="$log_file"

write_invocation() {
  local worktree_path=$1
  local focused=$2

  jq -cn \
    --arg cwd "${worktree_path:-$outside_path}" \
    --argjson focused "$focused" \
    --argjson with_worktree "$([[ -n $worktree_path ]] && printf true || printf false)" '
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
    --arg cwd "${worktree_path:-$outside_path}" \
    --argjson with_worktree "$([[ -n $worktree_path ]] && printf true || printf false)" '
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

expected_standard_log() {
  local cwd=$1

  printf 'tab\trename\ttab-claude\tClaude\n'
  for label in Codex OpenCode Pi Git Code Linear GitHub Shell; do
    printf 'tab\tcreate\t--workspace\tworkspace-1\t--cwd\t%s\t--label\t%s\t--no-focus\n' \
      "$cwd" "$label"
  done
}

expected_work_log() {
  expected_standard_log "$inside_path"
  printf 'pane\trun\tpane-claude\tclaude-fenced\n'
  printf 'pane\trun\t%s\tcodex-fenced\n' "$codex_pane_id"
  printf 'pane\trun\t%s\tlg\n' "$git_pane_id"
  printf 'pane\trun\t%s\tfresh .\n' "$code_pane_id"
  printf 'tab\tclose\t%s\n' "$opencode_tab_id"
  printf 'tab\tclose\t%s\n' "$pi_tab_id"
  printf 'tab\tfocus\ttab-claude\n'
}

run_standard_case() {
  local name=$1
  local path=$2
  local focused=$3
  local expected="$TMPDIR/expected-$name.log"

  write_invocation "$path" "$focused"
  : >"$log_file"
  run_layout >"$TMPDIR/$name.out"
  expected_standard_log "${path:-$outside_path}" >"$expected"
  cmp "$expected" "$log_file"
}

run_standard_case ordinary "" false
run_standard_case external "$outside_path" true
run_standard_case root "$chainguard_root" true
run_standard_case prefix "$prefix_path" true
run_standard_case escape "$escape_path" true
run_standard_case missing "$missing_path" true

write_invocation "$inside_path" false
: >"$log_file"
run_layout >"$TMPDIR/chainguard.out"
expected_work_log >"$work_log"
cmp "$work_log" "$log_file"
[[ $(tail -n 1 "$log_file") == $'tab\tfocus\ttab-claude' ]] \
  || fail "the Claude focus was not the final Herdr command"

: >"$log_file"
if HERDR_PLUGIN_EVENT=worktree.created \
  HERDR_PLUGIN_EVENT_JSON="$(<"$event_file")" \
  HERDR_PLUGIN_CONTEXT_JSON="$(<"$context_file")" \
  "$script" >"$TMPDIR/wrong-event.out" 2>&1; then
  fail "the wrong event case succeeded"
fi
[[ ! -s $log_file ]] || fail "the wrong event case called Herdr"

write_invocation "" true
jq '.workspace_id = "workspace-2"' "$context_file" >"$TMPDIR/mismatched-context.json"
mv "$TMPDIR/mismatched-context.json" "$context_file"
: >"$log_file"
if output=$(run_layout 2>&1); then
  fail "the mismatched context case succeeded"
fi
[[ ! -s $log_file ]] || fail "the mismatched context case called Herdr"
[[ $output == *"does not match the event context"* ]] || fail "the context error was not useful"

write_invocation "" true
: >"$log_file"
export FAKE_HERDR_FAIL_COMMAND="tab create --workspace workspace-1 --cwd $outside_path --label Git --no-focus"
if output=$(run_layout 2>&1); then
  fail "the tab creation failure case succeeded"
fi
unset FAKE_HERDR_FAIL_COMMAND
[[ $output == *"workspace workspace-1"* ]] || fail "the failure omitted the workspace ID"
[[ $output == *"partial workspace was preserved"* ]] || fail "the failure omitted recovery guidance"
[[ $(wc -l <"$log_file") -eq 5 ]] || fail "the layout continued after a tab creation failure"

write_invocation "" true
: >"$log_file"
export FAKE_HERDR_MALFORMED_COMMAND="tab rename tab-claude Claude"
if output=$(run_layout 2>&1); then
  fail "the malformed tab information case succeeded"
fi
unset FAKE_HERDR_MALFORMED_COMMAND
[[ $output == *"renaming the initial tab returned an invalid Herdr response"* ]] \
  || fail "the malformed tab information error was not useful"
[[ $(wc -l <"$log_file") -eq 1 ]] || fail "the layout continued after malformed tab information"

: >"$log_file"
export FAKE_HERDR_MISMATCH_COMMAND="tab rename tab-claude Claude"
if output=$(run_layout 2>&1); then
  fail "the mismatched tab information case succeeded"
fi
unset FAKE_HERDR_MISMATCH_COMMAND
[[ $output == *"renaming the initial tab returned an invalid Herdr response"* ]] \
  || fail "the mismatched tab information error was not useful"
[[ $(wc -l <"$log_file") -eq 1 ]] || fail "the layout continued after mismatched tab information"

: >"$log_file"
export FAKE_HERDR_MALFORMED_COMMAND="tab create --workspace workspace-1 --cwd $outside_path --label Codex --no-focus"
if output=$(run_layout 2>&1); then
  fail "the malformed tab creation case succeeded"
fi
unset FAKE_HERDR_MALFORMED_COMMAND
[[ $output == *"creating the Codex tab returned an invalid Herdr response"* ]] \
  || fail "the malformed tab creation error was not useful"
[[ $(wc -l <"$log_file") -eq 2 ]] || fail "the layout continued after a malformed tab creation response"

: >"$log_file"
export FAKE_HERDR_MISMATCH_COMMAND="tab create --workspace workspace-1 --cwd $outside_path --label Codex --no-focus"
if output=$(run_layout 2>&1); then
  fail "the mismatched tab creation case succeeded"
fi
unset FAKE_HERDR_MISMATCH_COMMAND
[[ $output == *"creating the Codex tab returned an invalid Herdr response"* ]] \
  || fail "the mismatched tab creation error was not useful"
[[ $(wc -l <"$log_file") -eq 2 ]] || fail "the layout continued after a mismatched tab creation response"

write_invocation "$inside_path" true
: >"$log_file"
export FAKE_HERDR_FAIL_COMMAND="pane run $git_pane_id lg"
if output=$(run_layout 2>&1); then
  fail "the pane run failure case succeeded"
fi
unset FAKE_HERDR_FAIL_COMMAND
[[ $output == *"running 'lg' in pane $git_pane_id failed"* ]] \
  || fail "the pane run failure error was not useful"
[[ $(wc -l <"$log_file") -eq 12 ]] || fail "the layout continued after a pane run failure"

: >"$log_file"
export FAKE_HERDR_FAIL_COMMAND="tab close $pi_tab_id"
if output=$(run_layout 2>&1); then
  fail "the tab closure failure case succeeded"
fi
unset FAKE_HERDR_FAIL_COMMAND
[[ $output == *"closing the Pi tab failed"* ]] || fail "the tab closure failure error was not useful"
[[ $output == *"finish the layout manually"* ]] || fail "the tab closure failure omitted recovery guidance"
[[ $(wc -l <"$log_file") -eq 15 ]] || fail "the layout continued after a tab closure failure"
[[ $(tail -n 1 "$log_file") == "tab"$'\t'"close"$'\t'"$pi_tab_id" ]] \
  || fail "the failed closure did not target the created Pi tab"

: >"$log_file"
export FAKE_HERDR_MISMATCH_COMMAND="tab focus tab-claude"
if output=$(run_layout 2>&1); then
  fail "the unfocused tab focus response case succeeded"
fi
unset FAKE_HERDR_MISMATCH_COMMAND
[[ $output == *"focusing the Claude tab returned an invalid Herdr response"* ]] \
  || fail "the unfocused tab focus response error was not useful"
[[ $(wc -l <"$log_file") -eq 16 ]] || fail "the layout did not stop after the unfocused tab focus response"

touch "$out"
