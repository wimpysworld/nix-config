set -euo pipefail

fail() {
  printf 'herdr-work-layout-test: %s\n' "$1" >&2
  exit 1
}

test_home="$TMPDIR/home"
chainguard_root="$test_home/Chainguard"
inside_path="$chainguard_root/project/feature"
outside_path="$test_home/Outside/project"
fake_bin="$TMPDIR/fake-bin"
missing_bin="$TMPDIR/missing-bin"
event_file="$TMPDIR/event.json"
context_file="$TMPDIR/context.json"
log_file="$TMPDIR/herdr.log"

mkdir -p "$inside_path" "$outside_path" "$fake_bin" "$missing_bin"
install -Dm755 "$fakeHerdr" "$fake_bin/herdr"
patchShebangs "$fake_bin/herdr"
for command_name in claude-fenced codex-fenced lazygit; do
  ln -s "$(type -P true)" "$fake_bin/$command_name"
done
for command_name in claude-fenced codex-fenced; do
  ln -s "$(type -P true)" "$missing_bin/$command_name"
done

export HOME="$test_home"
export FAKE_HERDR_LOG="$log_file"

write_invocation() {
  local event_fixture=$1
  local context_fixture=$2
  local worktree_path=$3

  jq --arg path "$worktree_path" '
    .data.worktree.path = $path
    | .data.workspace.worktree.checkout_path = $path
  ' "$event_fixture" >"$event_file"
  jq --arg path "$worktree_path" '
    .workspace_cwd = $path
    | .focused_pane_cwd = $path
    | .worktree.checkout_path = $path
  ' "$context_fixture" >"$context_file"
}

run_layout() {
  HERDR_ENV=1 \
    HERDR_BIN_PATH="$fake_bin/herdr" \
    HERDR_PLUGIN_EVENT=worktree.created \
    HERDR_PLUGIN_EVENT_JSON="$(<"$event_file")" \
    HERDR_PLUGIN_CONTEXT_JSON="$(<"$context_file")" \
    "$script"
}

write_invocation \
  "$fixtures/worktree-created-outside.json" \
  "$fixtures/context-outside.json" \
  "$outside_path"
: >"$log_file"
PATH="$fake_bin:$PATH" run_layout
[[ ! -s $log_file ]] || fail "the outside-root event called Herdr"

write_invocation \
  "$fixtures/worktree-created-inside.json" \
  "$fixtures/context-inside.json" \
  "$chainguard_root"
: >"$log_file"
PATH="$fake_bin:$PATH" run_layout
[[ ! -s $log_file ]] || fail "the Chainguard root event called Herdr"

write_invocation \
  "$fixtures/worktree-created-inside.json" \
  "$fixtures/context-inside.json" \
  "$inside_path"
: >"$log_file"
PATH="$fake_bin:$PATH" run_layout >"$TMPDIR/success.out"

expected_log="$TMPDIR/expected.log"
{
  printf 'workspace\trename\tworkspace-1\tfeature/agents\n'
  printf 'tab\trename\ttab-claude\tClaude\n'
  printf 'tab\tcreate\t--workspace\tworkspace-1\t--cwd\t%s\t--label\tCodex\t--no-focus\n' "$inside_path"
  printf 'tab\tcreate\t--workspace\tworkspace-1\t--cwd\t%s\t--label\tGit\t--no-focus\n' "$inside_path"
  printf 'tab\tcreate\t--workspace\tworkspace-1\t--cwd\t%s\t--label\tShell\t--no-focus\n' "$inside_path"
  printf 'pane\trun\tpane-claude\tclaude-fenced\n'
  printf 'pane\trun\tpane-codex\tcodex-fenced\n'
  printf 'pane\trun\tpane-git\tlazygit\n'
  printf 'tab\tfocus\ttab-claude\n'
} >"$expected_log"
cmp "$expected_log" "$log_file"

: >"$log_file"
if output=$(PATH="$missing_bin" run_layout 2>&1); then
  fail "the missing-command case succeeded"
fi
[[ ! -s $log_file ]] || fail "the missing-command case changed the workspace"
[[ $output == *"workspace workspace-1"* ]] || fail "the missing-command error omitted the workspace ID"
[[ $output == *"lazygit"* ]] || fail "the missing-command error omitted the command"

: >"$log_file"
export FAKE_HERDR_FAIL_COMMAND="tab create --workspace workspace-1 --cwd $inside_path --label Git --no-focus"
if output=$(PATH="$fake_bin:$PATH" run_layout 2>&1); then
  fail "the Herdr failure case succeeded"
fi
unset FAKE_HERDR_FAIL_COMMAND
[[ $output == *"workspace workspace-1"* ]] || fail "the Herdr failure error omitted the workspace ID"
[[ $output == *"partial workspace was preserved"* ]] || fail "the Herdr failure error omitted recovery guidance"
[[ $(wc -l <"$log_file") -eq 4 ]] || fail "the Herdr failure case continued after the failed call"

touch "$out"
