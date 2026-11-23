#!/usr/bin/env bash

# Render a single-line Catppuccin Mocha status bar for Antigravity CLI.
# Reads the statusLine JSON payload from stdin and always exits 0 so malformed
# or partial payloads never trip Antigravity's 30-failure disable threshold.

payload=""
IFS= read -r -d "" payload || true

if [[ -z "${payload//[[:space:]]/}" ]]; then
  exit 0
fi

# shellcheck disable=SC2016
jq_filter='
  if type != "object" then
    halt_error(1)
  else
    (
      if (.model | type) == "object" then
        if ((.model.display_name | type) == "string" and (.model.display_name | length) > 0) then
          .model.display_name
        elif ((.model.id | type) == "string" and (.model.id | length) > 0) then
          .model.id
        else
          ""
        end
      else
        ""
      end
    ),
    "\u0000",
    (
      if (.model | type) == "object" and (.model.effort | type) == "string" then
        .model.effort
      else
        ""
      end
    ),
    "\u0000",
    (
      if (.workspace | type) == "object" then
        .workspace as $w
        | if (($w.project_dir | type) == "string" and ($w.project_dir | length) > 0) then
            $w.project_dir
          elif (($w.current_dir | type) == "string" and ($w.current_dir | length) > 0) then
            $w.current_dir
          else
            ""
          end
      else
        ""
      end
    ),
    "\u0000",
    (
      if (.cost | type) == "object" and (.cost.total_usd | type) == "number" then
        (.cost.total_usd | tostring)
      else
        ""
      end
    ),
    "\u0000",
    (
      if (.context_window | type) == "object" and (.context_window.context_window_size | type) == "number" then
        (.context_window.context_window_size | tostring)
      else
        ""
      end
    ),
    "\u0000",
    (
      if (.context_window | type) == "object" then
        .context_window as $cw
        | if ($cw.used_percentage | type) == "number" then
            ($cw.used_percentage | tostring)
          elif (($cw.context_window_size | type) == "number" and $cw.context_window_size > 0) then
            if ($cw.current_usage | type) == "object" then
              (
                (
                  [
                    $cw.current_usage.input_tokens,
                    $cw.current_usage.output_tokens,
                    $cw.current_usage.cache_creation_input_tokens,
                    $cw.current_usage.cache_read_input_tokens
                  ]
                  | map(if type == "number" then . else 0 end)
                  | add
                ) / $cw.context_window_size * 100
                | tostring
              )
            elif (($cw.total_input_tokens | type) == "number" or ($cw.total_output_tokens | type) == "number") then
              (
                (
                  (if ($cw.total_input_tokens | type) == "number" then $cw.total_input_tokens else 0 end)
                  + (if ($cw.total_output_tokens | type) == "number" then $cw.total_output_tokens else 0 end)
                ) / $cw.context_window_size * 100
                | tostring
              )
            else
              "0"
            end
          else
            ""
          end
      else
        ""
      end
    ),
    "\u0000",
    (
      if (.context_window | type) == "object" then
        .context_window as $cw
        | if (($cw.context_window_size | type) == "number" and $cw.context_window_size > 0) then
            if ($cw.used_percentage | type) == "number" then
              (
                (
                  if $cw.used_percentage < 0 then 0
                  elif $cw.used_percentage > 100 then 100
                  else $cw.used_percentage
                  end
                ) * $cw.context_window_size / 100
                | round
                | tostring
              )
            elif ($cw.current_usage | type) == "object" then
              (
                [
                  $cw.current_usage.input_tokens,
                  $cw.current_usage.output_tokens,
                  $cw.current_usage.cache_creation_input_tokens,
                  $cw.current_usage.cache_read_input_tokens
                ]
                | map(if type == "number" and . > 0 then . else 0 end)
                | add
                | round
                | tostring
              )
            elif (($cw.total_input_tokens | type) == "number" or ($cw.total_output_tokens | type) == "number") then
              (
                (
                  (if ($cw.total_input_tokens | type) == "number" and $cw.total_input_tokens > 0 then $cw.total_input_tokens else 0 end)
                  + (if ($cw.total_output_tokens | type) == "number" and $cw.total_output_tokens > 0 then $cw.total_output_tokens else 0 end)
                )
                | round
                | tostring
              )
            else
              "0"
            end
          else
            ""
          end
      else
        ""
      end
    ),
    "\u0000"
  end
'

model_name=""
model_effort=""
workspace_dir=""
cost_usd=""
context_window_size=""
used_percentage=""
used_tokens=""

if ! {
  IFS= read -r -d "" model_name \
    && IFS= read -r -d "" model_effort \
    && IFS= read -r -d "" workspace_dir \
    && IFS= read -r -d "" cost_usd \
    && IFS= read -r -d "" context_window_size \
    && IFS= read -r -d "" used_percentage \
    && IFS= read -r -d "" used_tokens
} < <(jq -j "$jq_filter" <<< "$payload" 2>/dev/null); then
  exit 0
fi

color_model="${AGY_STATUSLINE_COLOR_MODEL:-}"
color_project="${AGY_STATUSLINE_COLOR_PROJECT:-}"
color_cost="${AGY_STATUSLINE_COLOR_COST:-}"
color_context="${AGY_STATUSLINE_COLOR_CONTEXT:-}"
color_isolation="${AGY_STATUSLINE_COLOR_ISOLATION:-}"
color_separator="${AGY_STATUSLINE_COLOR_SEPARATOR:-}"

paint() {
  local color="$1"
  local text="$2"
  if [[ -n "$color" ]]; then
    printf '\033[%sm%s\033[0m' "$color" "$text"
  else
    printf '%s' "$text"
  fi
}

segments=()

if [[ -n "$model_name" ]]; then
  if [[ -n "$model_effort" ]]; then
    name_lc="${model_name,,}"
    effort_lc="${model_effort,,}"
    if [[ "$name_lc" == *"($effort_lc)"* || "$name_lc" == *" $effort_lc" ]]; then
      model_label="$model_name"
    else
      model_label="$model_name $model_effort"
    fi
  else
    model_label="$model_name"
  fi
  segments+=("$(paint "$color_model" "$model_label")")
fi

if [[ -n "$workspace_dir" ]]; then
  project_name="$(basename -- "$workspace_dir")"
  if [[ -n "$project_name" ]]; then
    segments+=("$(paint "$color_project" "$project_name")")
  fi
fi

if [[ -n "$cost_usd" ]]; then
  cost_label="$(LC_ALL=C awk -v v="$cost_usd" 'BEGIN {
    v = v + 0
    if (v < 0) v = 0
    if (v < 1) printf "$%.4f", v
    else printf "$%.2f", v
  }')"
  segments+=("$(paint "$color_cost" "$cost_label")")
fi

if [[ -n "$context_window_size" ]]; then
  window_label="$(LC_ALL=C awk -v v="$context_window_size" 'BEGIN {
    v = v + 0
    if (v <= 0) exit
    if (v >= 999950) {
      s = sprintf("%.1f", v / 1000000)
      sub(/\.0$/, "", s)
      printf "%sM window", s
    } else if (v >= 1000) {
      s = sprintf("%.1f", v / 1000)
      sub(/\.0$/, "", s)
      printf "%sk window", s
    } else {
      printf "%d window", int(v + 0.5)
    }
  }')"
  if [[ -n "$window_label" ]]; then
    segments+=("$(paint "$color_context" "$window_label")")
  fi
fi

if [[ -n "$used_percentage" ]]; then
  used_label="$(LC_ALL=C awk -v v="$used_percentage" 'BEGIN {
    v = v + 0
    if (v < 0) v = 0
    if (v > 100) v = 100
    printf "Context %d%% used", int(v + 0.5)
  }')"
  segments+=("$(paint "$color_context" "$used_label")")
fi

isolation_label="${NOUGHTY_AGENT_ISOLATION:-Unfenced}"
segments+=("$(paint "$color_isolation" "$isolation_label")")

separator="$(paint "$color_separator" " · ")"

output=""
for i in "${!segments[@]}"; do
  if ((i > 0)); then
    output+="$separator"
  fi
  output+="${segments[$i]}"
done

printf '%s\n' "$output"

sync_herdr() {
  local pane_id="${HERDR_PANE_ID:-}"
  pane_id="${pane_id#"${pane_id%%[![:space:]]*}"}"
  pane_id="${pane_id%"${pane_id##*[![:space:]]}"}"
  if [[ "${HERDR_ENV:-}" != "1" || -z "$pane_id" ]]; then
    return 0
  fi

  local safe_pane_id="${pane_id//[^0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_-]/_}"
  if [[ -z "$safe_pane_id" ]]; then
    return 0
  fi

  local cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/agy-herdr"
  mkdir -p -- "$cache_dir" 2>/dev/null || return 0

  # Report model and effort to Herdr via herdr-disp-model when changed.
  local clean_model="$model_name"
  clean_model="${clean_model#"${clean_model%%[![:space:]]*}"}"
  clean_model="${clean_model%"${clean_model##*[![:space:]]}"}"

  local clean_effort="$model_effort"
  clean_effort="${clean_effort#"${clean_effort%%[![:space:]]*}"}"
  clean_effort="${clean_effort%"${clean_effort##*[![:space:]]}"}"

  if [[ -n "$clean_model" && -n "$clean_effort" ]]; then
    local suffix="(${clean_effort,,})"
    local clean_lc="${clean_model,,}"
    if [[ "$clean_lc" == *"$suffix" ]]; then
      local stripped="${clean_model:0:${#clean_model}-${#suffix}}"
      stripped="${stripped%"${stripped##*[![:space:]]}"}"
      if [[ -n "$stripped" ]]; then
        clean_model="$stripped"
      fi
    fi
  fi

  local herdr_disp_model="${AGY_HERDR_DISP_MODEL:-${AGY_STATUSLINE_HERDR_DISP_MODEL_DEFAULT:-}}"
  if [[ -n "$clean_model" && -n "$herdr_disp_model" && -x "$herdr_disp_model" ]]; then
    local model_cache_file="$cache_dir/${safe_pane_id}.model"
    local model_cache_key="${clean_model}"$'\t'"${clean_effort}"
    local cached_model=""
    if [[ -r "$model_cache_file" ]]; then
      cached_model="$(< "$model_cache_file")" || cached_model=""
    fi
    if [[ "$model_cache_key" != "$cached_model" ]]; then
      if "$herdr_disp_model" report --pane "$pane_id" --harness agy --model "$clean_model" --effort "$clean_effort" >/dev/null 2>&1; then
        local model_tmp=""
        if model_tmp="$(mktemp "$cache_dir/.${safe_pane_id}.model.XXXXXX" 2>/dev/null)"; then
          if printf '%s' "$model_cache_key" > "$model_tmp" 2>/dev/null && mv -f -- "$model_tmp" "$model_cache_file" 2>/dev/null; then
            :
          else
            rm -f -- "$model_tmp" 2>/dev/null || true
          fi
        fi
      fi
    fi
  fi

  # Write per-pane context usage JSON for herdr-ctx-bar when changed.
  if [[ -n "$context_window_size" && -n "$used_percentage" && -n "$used_tokens" ]]; then
    local ctx_json_file="$cache_dir/${safe_pane_id}.json"
    local ctx_cache_file="$cache_dir/${safe_pane_id}.ctx"
    local ctx_cache_key="${used_percentage}|${context_window_size}|${used_tokens}"
    local cached_ctx=""
    if [[ -r "$ctx_cache_file" ]]; then
      cached_ctx="$(< "$ctx_cache_file")" || cached_ctx=""
    fi
    if [[ ! -f "$ctx_json_file" || "$ctx_cache_key" != "$cached_ctx" ]]; then
      local updated_at=""
      updated_at="$(date +%s 2>/dev/null)" || return 0
      local json_tmp=""
      if json_tmp="$(mktemp "$cache_dir/.${safe_pane_id}.json.XXXXXX" 2>/dev/null)"; then
        # shellcheck disable=SC2016
        if jq -n \
          --argjson used_percentage "$used_percentage" \
          --argjson context_window_size "$context_window_size" \
          --argjson used_tokens "$used_tokens" \
          --argjson updated_at "$updated_at" \
          '{
            used_percentage: ($used_percentage | if . < 0 then 0 elif . > 100 then 100 else . end),
            context_window_size: $context_window_size,
            used_tokens: ($used_tokens | if . < 0 then 0 else . end),
            updated_at: $updated_at
          }' > "$json_tmp" 2>/dev/null \
          && mv -f -- "$json_tmp" "$ctx_json_file" 2>/dev/null; then
          local ctx_tmp=""
          if ctx_tmp="$(mktemp "$cache_dir/.${safe_pane_id}.ctx.XXXXXX" 2>/dev/null)"; then
            if printf '%s' "$ctx_cache_key" > "$ctx_tmp" 2>/dev/null && mv -f -- "$ctx_tmp" "$ctx_cache_file" 2>/dev/null; then
              :
            else
              rm -f -- "$ctx_tmp" 2>/dev/null || true
            fi
          fi
        else
          rm -f -- "$json_tmp" 2>/dev/null || true
        fi
      fi
    fi
  fi
}

sync_herdr || true
