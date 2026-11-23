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
      if (.cost | type) == "object" and (.cost.total_usd | type) == "number" and .cost.total_usd > 0 then
        (.cost.total_usd | tostring)
      else
        ""
      end
    ),
    "\u0000",
    (
      if (.quota | type) == "object" and (.quota | length) > 0 then
        .quota as $q
        | (
            (
              (if (.model | type) == "object" and (.model.id | type) == "string" then .model.id else "" end)
              + " "
              + (if (.model | type) == "object" and (.model.display_name | type) == "string" then .model.display_name else "" end)
            ) | ascii_downcase
          ) as $model_lc
        | (
            if ($model_lc | contains("claude")) then "claude"
            elif ($model_lc | contains("gpt")) then "gpt"
            else "gemini"
            end
          ) as $pref
        | (
            if ($q[$pref] | type) == "object" and $q[$pref].disabled != true and ($q[$pref].remaining_fraction | type) == "number" then
              $q[$pref]
            else
              (
                $q
                | to_entries
                | map(.value)
                | map(select(type == "object" and .disabled != true and (.remaining_fraction | type) == "number"))
                | first // null
              )
            end
          ) as $bucket
        | if $bucket != null then
            (
              ($bucket.remaining_fraction * 100)
              | if . < 0 then 0 elif . > 100 then 100 else . end
              | round
              | tostring
            ) + "% left"
          elif ($q.credits | type) == "object" and $q.credits.disabled != true and ($q.credits.remaining_amount | type) == "number" then
            "Credits " + ($q.credits.remaining_amount | if . < 0 then 0 else . end | round | tostring)
          else
            ""
          end
      else
        ""
      end
    ),
    "\u0000",
    (
      if (.transcript_path | type) == "string" and (.transcript_path | length) > 0 then
        .transcript_path
      else
        ""
      end
    ),
    "\u0000",
    (
      if (.conversation_id | type) == "string" and (.conversation_id | length) > 0 then
        .conversation_id
      elif (.session_id | type) == "string" and (.session_id | length) > 0 then
        .session_id
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
quota_label=""
transcript_path=""
conversation_id=""
context_window_size=""
used_percentage=""
used_tokens=""

if ! {
  IFS= read -r -d "" model_name \
    && IFS= read -r -d "" model_effort \
    && IFS= read -r -d "" workspace_dir \
    && IFS= read -r -d "" cost_usd \
    && IFS= read -r -d "" quota_label \
    && IFS= read -r -d "" transcript_path \
    && IFS= read -r -d "" conversation_id \
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

format_usd() {
  local prefix="$1"
  local amount="$2"
  LC_ALL=C awk -v p="$prefix" -v v="$amount" 'BEGIN {
    v = v + 0
    if (v <= 0) exit
    if (v < 1) printf "%s$%.4f", p, v
    else printf "%s$%.2f", p, v
  }'
}

# USD rates per 1M tokens aligned with pi/default.nix and opencode/default.nix.
# On 1 December 2026, gemini-4-carbon input/output/cacheRead rates become 4/20/0.20 USD per million tokens.
# shellcheck disable=SC2016
transcript_cost_filter='
  reduce (
    inputs
    | fromjson?
    | select(type == "object" and .type == "PLANNER_RESPONSE")
  ) as $r (
    0;
    if ($r.model | type) != "string" then
      .
    else
      ($r.model | ascii_downcase) as $model
      | (if ($r.input_tokens | type) == "number" and $r.input_tokens > 0 then $r.input_tokens else 0 end) as $in
      | (if ($r.cache_read_tokens | type) == "number" and $r.cache_read_tokens > 0 then $r.cache_read_tokens else 0 end) as $cache
      | (if ($r.output_tokens | type) == "number" and $r.output_tokens > 0 then $r.output_tokens else 0 end) as $out
      | (
          if ($model | startswith("gemini-4-neon")) then
            [3, 15, 0.15]
          elif ($model | startswith("gemini-4-hydrogen")) then
            [1.50, 7.50, 0.075]
          elif ($model | startswith("gemini-4-carbon")) then
            [2, 10, 0.10]
          elif ($model | startswith("gemini-3.1-pro")) then
            if ($in + $cache) > 200000 then
              [4, 18, 0.40]
            else
              [2, 12, 0.20]
            end
          elif ($model | startswith("gemini-3-flash")) then
            [0.50, 3, 0.05]
          elif ($model | startswith("gemini-3.1-flash-lite")) then
            [0.25, 1.50, 0.025]
          else
            null
          end
        ) as $rates
      | if $rates == null then
          .
        else
          . + (($in * $rates[0] + $out * $rates[1] + $cache * $rates[2]) / 1000000)
        end
    end
  )
'

resolve_transcript_path() {
  local raw_path="$1"
  local conv_id="$2"

  if [[ -n "$raw_path" && -f "$raw_path" && -r "$raw_path" ]]; then
    printf '%s' "$raw_path"
    return 0
  fi

  # Antigravity CLI 1.5.14 BuildStatusLineData joins ".../.gemini/antigravity/brain/..."
  # even though transcripts live under ".../.gemini/antigravity-cli/brain/...".
  if [[ "$raw_path" == *"/.gemini/antigravity/"* ]]; then
    local cli_path="${raw_path/\/.gemini\/antigravity\//\/.gemini\/antigravity-cli\/}"
    if [[ -f "$cli_path" && -r "$cli_path" ]]; then
      printf '%s' "$cli_path"
      return 0
    fi
  fi

  if [[ -n "$conv_id" && "$conv_id" != *"/"* && "$conv_id" != *".."* && -n "${HOME:-}" ]]; then
    local fallback="${HOME}/.gemini/antigravity-cli/brain/${conv_id}/.system_generated/logs/transcript.jsonl"
    if [[ -f "$fallback" && -r "$fallback" ]]; then
      printf '%s' "$fallback"
      return 0
    fi
  fi

  return 0
}

estimate_transcript_cost() {
  local path="$1"
  if [[ -z "$path" || ! -f "$path" || ! -r "$path" ]]; then
    return 0
  fi

  local stat_info=""
  stat_info="$(stat -c '%s %Y' -- "$path" 2>/dev/null)" || return 0
  local file_size="${stat_info%% *}"
  local file_mtime="${stat_info#* }"
  if [[ -z "$file_size" || -z "$file_mtime" ]]; then
    return 0
  fi

  local hash_line=""
  hash_line="$(printf '%s' "$path" | sha256sum 2>/dev/null)" || return 0
  local path_hash="${hash_line%% *}"
  if [[ -z "$path_hash" ]]; then
    return 0
  fi

  local cache_root="${XDG_CACHE_HOME:-${HOME:+$HOME/.cache}}"
  local cache_dir=""
  local cache_file=""
  if [[ -n "$cache_root" ]]; then
    cache_dir="${cache_root}/agy-statusline"
    cache_file="${cache_dir}/${path_hash}.cost"
    local cached_size="" cached_mtime="" cached_cost=""
    if [[ -r "$cache_file" ]]; then
      if read -r cached_size cached_mtime cached_cost < "$cache_file" 2>/dev/null \
        && [[ "$cached_size" == "$file_size" && "$cached_mtime" == "$file_mtime" && -n "$cached_cost" ]]; then
        printf '%s' "$cached_cost"
        return 0
      fi
    fi
  fi

  local total_cost=""
  if ! total_cost="$(jq -Rn "$transcript_cost_filter" < "$path" 2>/dev/null)"; then
    return 0
  fi
  if [[ -z "$total_cost" ]]; then
    return 0
  fi

  if [[ -n "$cache_dir" ]] && mkdir -p -- "$cache_dir" 2>/dev/null; then
    local cache_tmp=""
    if cache_tmp="$(mktemp "$cache_dir/.${path_hash}.cost.XXXXXX" 2>/dev/null)"; then
      if printf '%s %s %s\n' "$file_size" "$file_mtime" "$total_cost" > "$cache_tmp" 2>/dev/null \
        && mv -f -- "$cache_tmp" "$cache_file" 2>/dev/null; then
        :
      else
        rm -f -- "$cache_tmp" 2>/dev/null || true
      fi
    fi
  fi

  printf '%s' "$total_cost"
}

if [[ -n "$cost_usd" ]]; then
  cost_label="$(format_usd "" "$cost_usd")"
  if [[ -n "$cost_label" ]]; then
    segments+=("$(paint "$color_cost" "$cost_label")")
  fi
elif [[ -n "$quota_label" ]]; then
  segments+=("$(paint "$color_cost" "$quota_label")")
elif [[ -n "$transcript_path" || -n "$conversation_id" ]]; then
  resolved_transcript="$(resolve_transcript_path "$transcript_path" "$conversation_id")" || resolved_transcript=""
  if [[ -n "$resolved_transcript" ]]; then
    estimated_cost="$(estimate_transcript_cost "$resolved_transcript")" || estimated_cost=""
    if [[ -n "$estimated_cost" ]]; then
      cost_label="$(format_usd "~" "$estimated_cost")"
      if [[ -n "$cost_label" ]]; then
        segments+=("$(paint "$color_cost" "$cost_label")")
      fi
    fi
  fi
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
