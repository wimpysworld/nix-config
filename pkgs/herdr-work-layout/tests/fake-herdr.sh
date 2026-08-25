#!/usr/bin/env bash
set -euo pipefail

: "${FAKE_HERDR_LOG:?}"

{
  printf '%s' "$1"
  for argument in "${@:2}"; do
    printf '\t%s' "$argument"
  done
  printf '\n'
} >>"$FAKE_HERDR_LOG"

if [[ ${FAKE_HERDR_FAIL_COMMAND:-} == "$*" ]]; then
  printf 'fake Herdr failure\n' >&2
  exit 42
fi

if [[ ${FAKE_HERDR_MALFORMED_COMMAND:-} == "$*" ]]; then
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
    jq -cn \
      --arg tab_id "$3" \
      --arg label "$4" \
      '{id:"fake",result:{type:"tab_info",tab:{tab_id:$tab_id,workspace_id:"workspace-1",label:$label}}}'
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
    suffix=${label,,}
    jq -cn \
      --arg label "$label" \
      --arg workspace_id "$workspace_id" \
      --arg tab_id "tab-$suffix" \
      --arg pane_id "pane-$suffix" \
      '{id:"fake",result:{type:"tab_created",tab:{tab_id:$tab_id,workspace_id:$workspace_id,label:$label},root_pane:{pane_id:$pane_id,tab_id:$tab_id,workspace_id:$workspace_id}}}'
    ;;
  "pane run") ;;
  "tab focus")
    jq -cn \
      --arg tab_id "$3" \
      '{id:"fake",result:{type:"tab_info",tab:{tab_id:$tab_id,workspace_id:"workspace-1",label:"Claude"}}}'
    ;;
  *) exit 2 ;;
esac
