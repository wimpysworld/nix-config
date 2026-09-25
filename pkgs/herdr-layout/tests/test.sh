# Gate: just test-codex-launchers.
set -euo pipefail

fail() {
	printf 'herdr-layout-test: %s\n' "$1" >&2
	exit 1
}

case ${variant:-} in
home | work) ;;
*) fail "expected variant=home or variant=work" ;;
esac

test_home="$TMPDIR/home"
chainguard_root="$test_home/Chainguard"
inside_path="$chainguard_root/project/feature"
outside_path="$test_home/Outside/project"
review_path="$chainguard_root/project/review-123"
review_development_path="$test_home/Development/project/review-123"
missing_path="$chainguard_root/missing"
fake_bin="$TMPDIR/fake-bin"
event_file="$TMPDIR/event.json"
context_file="$TMPDIR/context.json"
log_file="$TMPDIR/herdr.log"
expected_file="$TMPDIR/expected.log"
codex_pane_id=opaque-pane-q19
git_pane_id=opaque-pane-w46
code_pane_id=opaque-pane-f38
shell_pane_id=opaque-pane-s30
pi_pane_id=opaque-pane-k73
declare -A pane_ids=()
declare -A pane_commands=([Git]=lg [Code]='fresh .' [Shell]=clear)

if [[ $variant == work ]]; then
	initial_label=Claude
	initial_command=claude-fenced
	pane_ids[Codex]=$codex_pane_id
	pane_commands[Codex]='codex-fenced --noughty-fresh'
	extra_pane_labels=(Codex Git Code Shell)
else
	initial_label=OpenCode
	initial_command=opencode-fenced
	pane_ids[Pi]=$pi_pane_id
	pane_commands[Pi]=pi-fenced
	extra_pane_labels=(Pi Git Code Shell)
fi
export FAKE_HERDR_TAB_LABEL="$initial_label"
pane_ids[Git]=$git_pane_id
pane_ids[Code]=$code_pane_id
pane_ids[Shell]=$shell_pane_id

mkdir -p "$inside_path" "$outside_path" "$review_path" \
	"$review_development_path" "$fake_bin"
install -Dm755 "$fakeHerdr" "$fake_bin/herdr"
patchShebangs "$fake_bin/herdr"

export HOME="$test_home"
export FAKE_HERDR_LOG="$log_file"

expected_shell_tabs() {
	local cwd=$1

	printf 'tab\trename\ttab-claude\t%s\n' "$initial_label"
	for label in "${extra_pane_labels[@]}"; do
		printf 'tab\tcreate\t--workspace\tworkspace-1\t--cwd\t%s\t--label\t%s\t--no-focus\n' \
			"$cwd" "$label"
	done
}

write_invocation() {
	local worktree_path=$1
	local focused=$2
	local cwd=${3:-${worktree_path:-$outside_path}}
	local linked=${4:-true}

	jq -cn \
		--arg cwd "$cwd" \
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
		--arg cwd "$cwd" \
		--argjson with_worktree "$([[ -n $worktree_path ]] && printf true || printf false)" '
      {
        workspace_id: "workspace-1",
        workspace_label: "project",
        workspace_cwd: $cwd,
        tab_id: "tab-claude",
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

run_standard_case() {
	local name=$1
	local cwd=$2
	local focused=$3

	write_invocation "" "$focused" "$cwd"
	: >"$log_file"
	run_layout >"$TMPDIR/$name.out"
	expected_shell_tabs "$cwd" >"$expected_file"
	printf 'pane\trun\tpane-claude\t%s\n' "$initial_command" >>"$expected_file"
	for label in "${extra_pane_labels[@]}"; do
		command_text=${pane_commands[$label]:-}
		[[ -n $command_text ]] || continue
		printf 'pane\trun\t%s\t%s\n' "${pane_ids[$label]}" "$command_text" >>"$expected_file"
	done
	printf 'tab\tfocus\ttab-claude\n' >>"$expected_file"
	cmp "$expected_file" "$log_file"
	[[ $(tail -n 1 "$log_file") == $'tab\tfocus\ttab-claude' ]] ||
		fail "the focus was not the final Herdr command in the $name case"
}

run_review_case() {
	local name=$1
	local path=$2

	write_invocation "$path" false
	: >"$log_file"
	run_layout >"$TMPDIR/review-$name.out"
	{
		printf 'tab\trename\ttab-claude\tCodex\n'
		printf 'pane\trun\tpane-claude\tcodex-fenced --noughty-fresh\n'
	} >"$expected_file"
	cmp "$expected_file" "$log_file"
}

[[ -f $fakeHerdr ]] || fail "the fake Herdr is missing"

# Shell-only spaces and worktree spaces take the same layout in every variant.
run_standard_case ordinary "$outside_path" true
run_standard_case root "$chainguard_root" true
run_standard_case inside "$inside_path" false
run_standard_case missing "$missing_path" true

if [[ $variant == work ]]; then
	# A `review-*` named linked worktree switches the workspace to Codex only.
	run_standard_case review-ordinary "$review_path" false
	run_review_case linked "$review_path"
	run_review_case middle "$chainguard_root/project/topic-review-123"
	run_review_case trailing-slash "$review_path/"
	run_review_case development "$review_development_path"

	# An unlinked worktree keeps the standard layout instead of review mode.
	write_invocation "$review_development_path" false
	jq '.data.workspace.worktree.is_linked_worktree = false' "$event_file" >"$TMPDIR/staged.json"
	mv "$TMPDIR/staged.json" "$event_file"
	jq '.worktree.is_linked_worktree = false' "$context_file" >"$TMPDIR/staged.json"
	mv "$TMPDIR/staged.json" "$context_file"
	: >"$log_file"
	run_layout >"$TMPDIR/review-unlinked.out"
	expected_shell_tabs "$review_development_path" >"$expected_file"
	printf 'pane\trun\tpane-claude\tclaude-fenced\n' >>"$expected_file"
	printf 'pane\trun\t%s\tcodex-fenced --noughty-fresh\n' "$codex_pane_id" >>"$expected_file"
	printf 'pane\trun\t%s\tlg\n' "$git_pane_id" >>"$expected_file"
	printf 'pane\trun\t%s\tfresh .\n' "$code_pane_id" >>"$expected_file"
	printf 'pane\trun\t%s\tclear\n' "$shell_pane_id" >>"$expected_file"
	printf 'tab\tfocus\ttab-claude\n' >>"$expected_file"
	cmp "$expected_file" "$log_file"
fi

# The plugin rejects unexpected events without calling Herdr.
run_standard_case wrong-event "$outside_path" true
: >"$log_file"
if HERDR_PLUGIN_EVENT=worktree.created \
	HERDR_PLUGIN_EVENT_JSON="$(<"$event_file")" \
	HERDR_PLUGIN_CONTEXT_JSON="$(<"$context_file")" \
	"$script" >"$TMPDIR/wrong-event.out" 2>&1; then
	fail "the wrong event case succeeded"
fi
[[ ! -s $log_file ]] || fail "the wrong event case called Herdr"

# A mismatched context is reported with guidance and without Herdr calls.
write_invocation "" true
jq '.workspace_id = "workspace-2"' "$context_file" >"$TMPDIR/staged.json"
mv "$TMPDIR/staged.json" "$context_file"
: >"$log_file"
if output=$(run_layout 2>&1); then
	fail "the mismatched context case succeeded"
fi
[[ ! -s $log_file ]] || fail "the mismatched context case called Herdr"
[[ $output == *"does not match the event context"* ]] || fail "the context error was not useful"
[[ $output == *"finish the layout manually"* ]] || fail "the context error omitted recovery guidance"

# A tab creation failure stops before further tab creation.
first_pane_label=${extra_pane_labels[0]}
write_invocation "" true
: >"$log_file"
export FAKE_HERDR_FAIL_COMMAND="tab create --workspace workspace-1 --cwd $outside_path --label $first_pane_label --no-focus"
if output=$(run_layout 2>&1); then
	fail "the tab creation failure case succeeded"
fi
unset FAKE_HERDR_FAIL_COMMAND
[[ $output == *"workspace workspace-1"* ]] || fail "the failure omitted the workspace ID"
[[ $output == *"partial workspace was preserved"* ]] || fail "the failure omitted recovery guidance"
[[ $(wc -l <"$log_file") -eq 2 ]] || fail "the layout continued after a tab creation failure"

# A pane run failure stops the remaining pane commands and keeps guidance.
write_invocation "" true
: >"$log_file"
export FAKE_HERDR_FAIL_COMMAND="pane run $git_pane_id lg"
if output=$(run_layout 2>&1); then
	fail "the pane run failure case succeeded"
fi
unset FAKE_HERDR_FAIL_COMMAND
[[ $output == *"running 'lg' in pane $git_pane_id failed"* ]] ||
	fail "the pane run failure error was not useful"
[[ $output == *"finish the layout manually"* ]] || fail "the pane run failure omitted recovery guidance"
[[ $(grep -c $'^pane\trun\t'$git_pane_id$'\t' "$log_file") -eq 1 ]] ||
	fail "the layout continued after a pane run failure"

# A focus response that reports an unfocused tab stops the layout.
write_invocation "" true
: >"$log_file"
export FAKE_HERDR_MISMATCH_COMMAND="tab focus tab-claude"
if output=$(run_layout 2>&1); then
	fail "the unfocused tab focus response case succeeded"
fi
unset FAKE_HERDR_MISMATCH_COMMAND
[[ $output == *"focusing the $initial_label tab returned an invalid Herdr response"* ]] ||
	fail "the unfocused tab focus response error was not useful"
[[ $(tail -n 1 "$log_file") == "tab"$'\t'"focus"$'\t'"tab-claude" ]] ||
	fail "the failed focus did not target the initial tab"

touch "$out"
