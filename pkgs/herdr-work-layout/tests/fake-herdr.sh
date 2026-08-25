#!/usr/bin/env bash
set -euo pipefail

: "${FAKE_HERDR_LOG:?}"
command_text=$*

{
  printf '%s' "$1"
  for argument in "${@:2}"; do
    printf '\t%s' "$argument"
  done
  printf '\n'
} >>"$FAKE_HERDR_LOG"

if [[ ${FAKE_HERDR_FAIL_COMMAND:-} == "$command_text" ]]; then
  printf 'fake Herdr failure\n' >&2
  exit 42
fi

if [[ ${FAKE_HERDR_MALFORMED_COMMAND:-} == "$command_text" ]]; then
  printf '{"id":"fake","result":{"type":"tab_created"}}\n'
  exit 0
fi

case "$1 $2" in
  "workspace rename")
    jq -cn \
      --arg workspace_id "$3" \
      --arg label "$4" \
      '{id:"fake",result:{type:"workspace_info",workspace:{workspace_id:$workspace_id,label:$label}}}'
    ;;
  "tab rename")
    returned_label=$4
    if [[ ${FAKE_HERDR_MISMATCH_COMMAND:-} == "$command_text" ]]; then
      returned_label=Unexpected
    fi
    jq -cn \
      --arg tab_id "$3" \
      --arg label "$returned_label" '
        {
          id: "fake",
          result: {
            type: "tab_info",
            tab: {
              tab_id: $tab_id,
              workspace_id: "workspace-1",
              number: 1,
              label: $label,
              focused: false,
              pane_count: 1,
              agent_status: "idle"
            }
          }
        }
      '
    ;;
  "tab create")
    label=
    workspace_id=
    while (($# > 0)); do
      case "$1" in
        --label)
          label=$2
          shift 2
          ;;
        --workspace)
          workspace_id=$2
          shift 2
          ;;
        *) shift ;;
      esac
    done
    [[ -n $label && -n $workspace_id ]] || exit 2
    case "$label" in
      Codex)
        tab_id=opaque-tab-a71
        pane_id=opaque-pane-q19
        terminal_id=opaque-terminal-901
        number=2
        ;;
      OpenCode)
        tab_id=opaque-tab-m44
        pane_id=opaque-pane-b62
        terminal_id=opaque-terminal-347
        number=3
        ;;
      Pi)
        tab_id=opaque-tab-z08
        pane_id=opaque-pane-k73
        terminal_id=opaque-terminal-582
        number=4
        ;;
      Git)
        tab_id=opaque-tab-c25
        pane_id=opaque-pane-w46
        terminal_id=opaque-terminal-163
        number=5
        ;;
      Code)
        tab_id=opaque-tab-r91
        pane_id=opaque-pane-f38
        terminal_id=opaque-terminal-724
        number=6
        ;;
      Linear)
        tab_id=opaque-tab-h36
        pane_id=opaque-pane-n05
        terminal_id=opaque-terminal-819
        number=7
        ;;
      GitHub)
        tab_id=opaque-tab-v52
        pane_id=opaque-pane-d87
        terminal_id=opaque-terminal-256
        number=8
        ;;
      Shell)
        tab_id=opaque-tab-j64
        pane_id=opaque-pane-s30
        terminal_id=opaque-terminal-438
        number=9
        ;;
      *) exit 2 ;;
    esac
    root_tab_id=$tab_id
    if [[ ${FAKE_HERDR_MISMATCH_COMMAND:-} == "$command_text" ]]; then
      root_tab_id=opaque-tab-unrelated
    fi
    jq -cn \
      --arg label "$label" \
      --arg workspace_id "$workspace_id" \
      --arg tab_id "$tab_id" \
      --arg pane_id "$pane_id" \
      --arg terminal_id "$terminal_id" \
      --arg root_tab_id "$root_tab_id" \
      --argjson number "$number" '
        {
          id: "fake",
          result: {
            type: "tab_created",
            tab: {
              tab_id: $tab_id,
              workspace_id: $workspace_id,
              number: $number,
              label: $label,
              focused: false,
              pane_count: 1,
              agent_status: "idle"
            },
            root_pane: {
              pane_id: $pane_id,
              terminal_id: $terminal_id,
              workspace_id: $workspace_id,
              tab_id: $root_tab_id,
              focused: false,
              agent_status: "idle",
              revision: 0
            }
          }
        }
      '
    ;;
  "pane run")
    ;;
  "tab close")
    jq -cn '{id:"fake",result:{type:"ok"}}'
    ;;
  "tab focus")
    focused=true
    if [[ ${FAKE_HERDR_MISMATCH_COMMAND:-} == "$command_text" ]]; then
      focused=false
    fi
    jq -cn \
      --arg tab_id "$3" \
      --argjson focused "$focused" '
        {
          id: "fake",
          result: {
            type: "tab_info",
            tab: {
              tab_id: $tab_id,
              workspace_id: "workspace-1",
              number: 1,
              label: "Claude",
              focused: $focused,
              pane_count: 1,
              agent_status: "idle"
            }
          }
        }
      '
    ;;
  *) exit 2 ;;
esac
