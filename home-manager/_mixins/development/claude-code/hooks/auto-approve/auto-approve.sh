#!/usr/bin/env bash
#
# Claude Code PreToolUse hook: auto-approve safe Bash invocations.
#
# Goal: stop prompting on commands that are obviously safe even when wrapped in
# shapes that Claude Code's static `Bash(cmd:*)` matcher does not handle. The
# stock matcher splits on shell operators and matches each leaf, but it has
# documented gaps around redirects, command substitution, heredocs, env-var
# prefixes, and several wrappers. We close those gaps from outside.
#
# Decision model (mirrors Claude Code's tier ordering: deny > defer > allow):
#
#   1. Hard-deny: any leaf matches a known-dangerous shape, even via wrappers
#      or substitution. Returns permissionDecision = "deny".
#   2. Allow: every leaf is on the read-only safe-set OR is a `--help` /
#      `--version` invocation for a non-deny-listed command. Returns
#      permissionDecision = "allow".
#   3. Defer: anything else. Exit 0 with no JSON, letting Claude Code's
#      normal allow/ask/deny rules decide.
#
# We never weaken the security boundary: every entry in `bashDeny` stays in
# place, and this script tightens coverage by also rejecting wrapper-disguised
# variants the static rules cannot express.

set -euo pipefail

# ---------------------------------------------------------------------------
# I/O helpers
# ---------------------------------------------------------------------------

emit_decision() {
	# $1 = "allow" | "deny", $2 = reason
	jq -nc \
		--arg decision "$1" \
		--arg reason "$2" \
		'{
      hookSpecificOutput: {
        hookEventName: "PreToolUse",
        permissionDecision: $decision,
        permissionDecisionReason: $reason
      }
    }'
	exit 0
}

defer() {
	# No output, exit 0 -> Claude Code applies its normal permission flow.
	exit 0
}

# ---------------------------------------------------------------------------
# Static policy tables
# ---------------------------------------------------------------------------

# Commands that are read-only or otherwise safe enough to run without prompting,
# regardless of their arguments. Mirrors the read-only entries in `bashAllow`
# in default.nix. Claude Code already auto-runs many of these, but we list them
# again so pipelines like `journalctl -u foo | jq` evaluate to "all leaves
# safe" without depending on the upstream built-in set.
KNOWN_SAFE_COMMANDS=(
	# Coreutils and inspection
	ls cat head tail wc file tree pwd which type env fd rg grep egrep fgrep
	whoami hostname uname df free ps top uptime date lscpu lsblk lsusb lspci
	id groups printenv basename dirname realpath stat du sort uniq cut awk
	diff cmp less more tr tac rev seq md5sum sha256sum shasum jq yq bc man
	tldr strings column fold nl pr expand unexpand paste join comm
	# Archive inspection (read-only modes only; deny pipelines below catch
	# write modes)
	zcat bzcat xzcat zless bzless xzless zipinfo
	# Network inspection
	ping traceroute dig host nslookup
	# Process inspection
	pgrep pidof pstree lsof
	# Alternative pagers
	bat most
	# Dev helpers
	xxd hexdump od base64 base32 shellcheck luacheck
	# Build-tool version probes are caught by the help/version rule, but the
	# binaries are listed here so things like `make -n` (already a safe subcmd)
	# aren't blocked. Discrimination on subcommand happens separately if needed.
	pkg-config pkgconf nm objdump readelf ldd
	# systemd inspection
	hostnamectl timedatectl loginctl localectl networkctl resolvectl busctl
	coredumpctl systemd-analyze
	# Identify is read-only ImageMagick
	identify
	# Nix inspection-only commands
	nix-info nix-tree nix-diff nvd statix deadnix nixfmt alejandra
	# Note: `just` is intentionally NOT listed. It used to be here so the
	# hook could auto-approve safe recipes, but Claude Code's hook contract
	# states ask rules still prompt even when a hook returns "allow"
	# (https://code.claude.com/docs/en/hooks.md). Specific `just` recipes
	# are allow-listed in default.nix instead, and unknown subcommands fall
	# through to the default prompt.
)

# Commands that this hook will NEVER auto-approve, even for `--help`/`--version`.
# These mirror entries from `bashDeny` in default.nix plus a few extras. The
# command name (post env-strip, post wrapper-strip) is checked against this
# list. If a leaf's command name is here, the leaf cannot be auto-approved by
# the help/version rule; it falls through to defer (or hits a hard-deny shape
# below).
DENY_COMMANDS=(
	sudo doas pkexec
	shred wipe srm
	dd
	mkfs mkfs.ext2 mkfs.ext3 mkfs.ext4 mkfs.btrfs mkfs.xfs mkfs.vfat mkfs.fat
	fdisk parted gparted sfdisk cfdisk
	mkswap swapon swapoff
	mount umount
	sysctl modprobe insmod rmmod
	grub-install update-grub efibootmgr
	rm rmdir
	nix-collect-garbage
)

# ---------------------------------------------------------------------------
# Hard-deny shape detection (regex against the full command line)
# ---------------------------------------------------------------------------
#
# Each entry is "regex|reason". The regex is matched against the full command
# string after stripping comments (so a `# rm -rf /` comment is not mistaken
# for an invocation). Anchors are loose by design: a dangerous shape buried
# inside a `$(...)` or `&&` is still a dangerous shape.

hard_deny_shape() {
	local cmd="$1"

	# rm -rf against root, home, $HOME or ~ with optional whitespace
	if [[ $cmd =~ rm[[:space:]]+(-[a-zA-Z]*r[a-zA-Z]*f[a-zA-Z]*|-[a-zA-Z]*f[a-zA-Z]*r[a-zA-Z]*|--recursive[[:space:]]+--force|--force[[:space:]]+--recursive)[[:space:]]+(/|~|\$HOME|/\*|~/\*|\$HOME/\*) ]]; then
		emit_decision deny "rm -rf against root or home is never allowed"
	fi

	# sudo anywhere on the line, including via env prefix or after a wrapper
	if [[ $cmd =~ (^|[^A-Za-z0-9_/.-])sudo[[:space:]] ]]; then
		emit_decision deny "sudo is denied; run privileged operations outside Claude"
	fi
	if [[ $cmd =~ (^|[^A-Za-z0-9_/.-])(doas|pkexec)[[:space:]] ]]; then
		emit_decision deny "privilege-escalation tools are denied"
	fi

	# Secure-delete utilities
	if [[ $cmd =~ (^|[^A-Za-z0-9_/.-])(shred|wipe|srm)[[:space:]] ]]; then
		emit_decision deny "secure-delete tools are denied"
	fi

	# dd with input or output args (plain `dd --version` is fine, hits help rule)
	if [[ $cmd =~ (^|[^A-Za-z0-9_/.-])dd[[:space:]]+([^|;&]*[[:space:]])?(if|of)= ]]; then
		emit_decision deny "dd with if=/of= is denied"
	fi

	# Disk formatting / partitioning
	if [[ $cmd =~ (^|[^A-Za-z0-9_/.-])(mkfs(\.[a-z0-9]+)?|fdisk|parted|gparted|sfdisk|cfdisk|mkswap|swapon|swapoff)[[:space:]] ]]; then
		emit_decision deny "disk-formatting / swap tools are denied"
	fi

	# Power management via systemd
	if [[ $cmd =~ systemctl[[:space:]]+(poweroff|reboot|halt|suspend|hibernate)([[:space:]]|$) ]]; then
		emit_decision deny "power-management is denied"
	fi

	# Nix garbage collection / store deletion
	if [[ $cmd =~ (^|[^A-Za-z0-9_/.-])nix-collect-garbage([[:space:]]|$) ]] ||
		[[ $cmd =~ nix-store[[:space:]]+(--gc|--delete)([[:space:]]|$) ]] ||
		[[ $cmd =~ nix[[:space:]]+upgrade-nix([[:space:]]|$) ]]; then
		emit_decision deny "Nix garbage collection / upgrade is denied"
	fi

	# Destructive git history rewrites
	if [[ $cmd =~ git[[:space:]]+push[[:space:]]+(-f|--force|--force-with-lease) ]] ||
		[[ $cmd =~ git[[:space:]]+reset[[:space:]]+--hard ]] ||
		[[ $cmd =~ git[[:space:]]+filter-branch ]] ||
		[[ $cmd =~ git[[:space:]]+clean[[:space:]]+(-[a-zA-Z]*[fdx]|--force) ]]; then
		emit_decision deny "destructive git history rewrites are denied"
	fi

	# Mass docker prune
	if [[ $cmd =~ docker[[:space:]]+(system|volume|container|image)[[:space:]]+prune ]]; then
		emit_decision deny "mass docker prune is denied"
	fi

	# Remote-resource deletion
	if [[ $cmd =~ gh[[:space:]]+repo[[:space:]]+delete ]] ||
		[[ $cmd =~ (^|[^A-Za-z0-9_/.-])wrangler[[:space:]]+delete ]]; then
		emit_decision deny "remote-resource deletion is denied"
	fi

	# Subshell -c bypass: a model could route any command through `bash -c '...'`
	# and evade per-leaf static matching. The interior is opaque to us, so deny.
	# Matched even through wrappers (`xargs sh -c`, `flock sh -c`) and env
	# prefixes (`SHELL=foo bash -c`). The `[[:space:]]|=|$` trailing class also
	# covers a bare `sh -c` at end of line, which a model could feed via xargs.
	if [[ $cmd =~ (^|[^A-Za-z0-9_/.-])(bash|sh|zsh|fish|dash|ksh|busybox)[[:space:]]+-i?c([[:space:]]|=|$) ]]; then
		emit_decision deny "subshell -c bypass is denied"
	fi

	# Interpreter -c / -e / --eval bypass
	if [[ $cmd =~ (^|[^A-Za-z0-9_/.-])(python|python2|python3|node|nodejs|perl|ruby|lua|php)[[:space:]]+(-c|-e|--eval|-r|--exec)([[:space:]]|=|$) ]]; then
		emit_decision deny "interpreter -c/-e bypass is denied"
	fi

	# Bare `eval` is never legitimate from the agent
	if [[ $cmd =~ (^|[^A-Za-z0-9_/.-])eval[[:space:]] ]]; then
		emit_decision deny "eval is denied"
	fi
}

# ---------------------------------------------------------------------------
# Command-line decomposition
# ---------------------------------------------------------------------------

# Split the command line into top-level "leaves". Operators that produce a new
# leaf: `&&`, `||`, `;`, `|`, `|&`, `&` (job control), and newlines. A leaf is
# the run of bytes between operators, with surrounding whitespace trimmed.
#
# Quoting and brace/paren depth must be respected so we don't split inside a
# `$(...)` or a quoted string. We track:
#   - single-quote depth (0 or 1; no escapes inside '...')
#   - double-quote depth (0 or 1; backslashes escape next char)
#   - paren depth for `$(...)` and `(...)` subshells
#   - brace depth for `${...}` and `{...}` groups
#
# Pure bash; no fork-per-character.
split_leaves() {
	local s="$1"
	local len=${#s}
	local i=0 ch nch prev
	local sq=0 dq=0 paren=0 brace=0 backtick=0
	local buf=""
	local -a leaves=()
	# Pre-computed single-character constants so shellcheck doesn't trip over a
	# bare `'\'` literal (SC1003).
	local bslash=$'\\'

	while ((i < len)); do
		ch=${s:i:1}
		nch=${s:i+1:1}

		# Backslash escapes: copy the next byte verbatim (outside single quotes).
		if [[ $sq -eq 0 && $ch == "$bslash" && $i -lt $((len - 1)) ]]; then
			buf+="$ch$nch"
			i=$((i + 2))
			continue
		fi

		# Quote toggles
		if [[ $dq -eq 0 && $ch == "'" ]]; then
			sq=$((sq == 0 ? 1 : 0))
			buf+="$ch"
			i=$((i + 1))
			continue
		fi
		if [[ $sq -eq 0 && $ch == '"' ]]; then
			dq=$((dq == 0 ? 1 : 0))
			buf+="$ch"
			i=$((i + 1))
			continue
		fi
		if [[ $sq -eq 0 && $dq -eq 0 && $ch == '`' ]]; then
			backtick=$((backtick == 0 ? 1 : 0))
			buf+="$ch"
			i=$((i + 1))
			continue
		fi

		# Inside single quotes nothing is special.
		if [[ $sq -eq 1 ]]; then
			buf+="$ch"
			i=$((i + 1))
			continue
		fi

		# Track paren/brace nesting (so `&&` inside `$(a && b)` doesn't split).
		if [[ $ch == '(' ]]; then
			paren=$((paren + 1))
			buf+="$ch"
			i=$((i + 1))
			continue
		fi
		if [[ $ch == ')' && $paren -gt 0 ]]; then
			paren=$((paren - 1))
			buf+="$ch"
			i=$((i + 1))
			continue
		fi
		if [[ $ch == '{' ]]; then
			brace=$((brace + 1))
			buf+="$ch"
			i=$((i + 1))
			continue
		fi
		if [[ $ch == '}' && $brace -gt 0 ]]; then
			brace=$((brace - 1))
			buf+="$ch"
			i=$((i + 1))
			continue
		fi

		# Only split at top level (no open quote/paren/brace/backtick).
		if [[ $dq -eq 0 && $paren -eq 0 && $brace -eq 0 && $backtick -eq 0 ]]; then
			# Two-character operators: && || |& ;;
			if [[ $ch == '&' && $nch == '&' ]] ||
				[[ $ch == '|' && $nch == '|' ]] ||
				[[ $ch == '|' && $nch == '&' ]] ||
				[[ $ch == ';' && $nch == ';' ]]; then
				leaves+=("$buf")
				buf=""
				i=$((i + 2))
				continue
			fi
			# `&` is a separator EXCEPT when it's part of a redirect merge:
			# `2>&1`, `>&-`, `<&3`, `&>file`, `&>>file`. Inspect the previous and
			# next bytes to disambiguate. The previous byte at the buffer's tail
			# tells us if we're in a `>&` or `<&` form; the next byte tells us if
			# we're starting a `&>` form.
			if [[ $ch == '&' ]]; then
				prev=${buf: -1}
				if [[ $prev == '>' || $prev == '<' || $nch == '>' ]]; then
					buf+="$ch"
					i=$((i + 1))
					continue
				fi
			fi
			# Single-character separators: | ; & newline
			if [[ $ch == '|' || $ch == ';' || $ch == '&' || $ch == $'\n' ]]; then
				leaves+=("$buf")
				buf=""
				i=$((i + 1))
				continue
			fi
		fi

		buf+="$ch"
		i=$((i + 1))
	done

	if [[ -n $buf ]]; then
		leaves+=("$buf")
	fi

	# Trim each leaf and emit one per line.
	local leaf
	for leaf in "${leaves[@]}"; do
		# shellcheck disable=SC2001
		leaf=$(printf '%s' "$leaf" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')
		[[ -n $leaf ]] && printf '%s\n' "$leaf"
	done
}

# Extract the contents of every $(...) and `...` substitution as additional
# pseudo-leaves. We need the contents because the outer command's first token
# might be safe (`echo`, `printf`) while the substitution runs something
# dangerous. Recurses one level; deeper nesting is rare and conservatively
# deferred.
extract_substitutions() {
	local s="$1"
	# Bash regex with backreferences won't match nested parens reliably; use a
	# simple stack walker.
	local len=${#s}
	local i=0 ch
	local depth=0
	local buf=""
	local in_dollar=0

	while ((i < len)); do
		ch=${s:i:1}
		if [[ $in_dollar -eq 0 && $ch == '$' && ${s:i+1:1} == '(' && ${s:i+2:1} != '(' ]]; then
			in_dollar=1
			depth=1
			i=$((i + 2))
			buf=""
			continue
		fi
		if [[ $in_dollar -eq 1 ]]; then
			if [[ $ch == '(' ]]; then
				depth=$((depth + 1))
				buf+="$ch"
			elif [[ $ch == ')' ]]; then
				depth=$((depth - 1))
				if [[ $depth -eq 0 ]]; then
					printf '%s\n' "$buf"
					in_dollar=0
					buf=""
				else
					buf+="$ch"
				fi
			else
				buf+="$ch"
			fi
			i=$((i + 1))
			continue
		fi
		# Backtick substitution
		if [[ $ch == '`' ]]; then
			local j=$((i + 1))
			while ((j < len)) && [[ ${s:j:1} != '`' ]]; do
				j=$((j + 1))
			done
			if ((j < len)); then
				printf '%s\n' "${s:i+1:j-i-1}"
				i=$((j + 1))
				continue
			fi
		fi
		i=$((i + 1))
	done
}

# Remove redirect tokens from a leaf so the bare command can be classified.
# Handles: `>`, `>>`, `<`, `<<<` (here-string), `2>`, `2>>`, `2>&1`, `&>`, `&>>`,
# `n>file`, `n>>file`, `n<file`, `n<&m`, `n>&m`, `n>&-`, `n<&-`, with optional
# spaces between operator and target. Heredoc delimiters (`<<EOF`) are stripped
# along with the rest of the line; the heredoc body sits in subsequent leaves
# (newline-separated) which we'll also see.
strip_redirects() {
	local leaf="$1"
	# Strip `[n]>>file`, `[n]>file`, `[n]<file`, `[n]<<<word`, `2>&1`, `&>file`, etc.
	# Process iteratively because multiple redirects can appear on one leaf.
	local prev=""
	while [[ $leaf != "$prev" ]]; do
		prev=$leaf
		# Heredoc delimiter and its (optional) tab-strip variant: strip the `<<-?WORD`
		# token entirely; the body content arrives as later leaves and is matched
		# in its own right.
		leaf=$(printf '%s' "$leaf" | sed -E "s/[[:space:]]*[0-9]*<<-?[[:space:]]*'?\"?[A-Za-z_][A-Za-z0-9_]*'?\"?[[:space:]]*//g")
		# Here-strings: `<<<word` or `<<< word`
		leaf=$(printf '%s' "$leaf" | sed -E 's/[[:space:]]*[0-9]*<<<[[:space:]]*[^[:space:]|;&]+//g')
		# Combined &> and &>>
		leaf=$(printf '%s' "$leaf" | sed -E 's/[[:space:]]*&>>?[[:space:]]*[^[:space:]|;&<>]+//g')
		# Stream merges: `2>&1`, `1>&2`, `>&-`, `<&-`
		leaf=$(printf '%s' "$leaf" | sed -E 's/[[:space:]]*[0-9]*[<>]&[0-9-]+//g')
		# File redirects: `>file`, `>>file`, `<file`, `2>file`, etc.
		leaf=$(printf '%s' "$leaf" | sed -E 's/[[:space:]]*[0-9]*>>?[[:space:]]*[^[:space:]|;&<>]+//g')
		leaf=$(printf '%s' "$leaf" | sed -E 's/[[:space:]]*[0-9]*<[[:space:]]*[^[:space:]|;&<>]+//g')
	done
	# Trim
	printf '%s' "$leaf" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//'
}

# Strip leading `VAR=val VAR2=val2` env assignments. POSIX permits this prefix
# before any simple command, and Claude Code's own matcher documents the same
# stripping behaviour. We mirror it so a leaf like `CI=true gh pr list` is
# classified by `gh`, not by `CI=true`.
strip_env_prefix() {
	local leaf="$1"
	# Match runs of `IDENT=value ` where value is either quoted or unquoted up
	# to the next space. We do this iteratively so multiple assignments strip.
	local prev=""
	while [[ $leaf != "$prev" ]]; do
		prev=$leaf
		if [[ $leaf =~ ^[A-Za-z_][A-Za-z0-9_]*=([^[:space:]]*|\"[^\"]*\"|\'[^\']*\')[[:space:]]+(.*)$ ]]; then
			leaf="${BASH_REMATCH[2]}"
		else
			break
		fi
	done
	printf '%s' "$leaf"
}

# Strip approved transparent wrappers from the front of a leaf. Claude Code
# strips a fixed wrapper allow-list (`timeout`, `time`, `nice`, `nohup`,
# `stdbuf`, bare `xargs`) before matching; we mirror it. Note `sudo` is NOT in
# this list and is intentionally caught by hard_deny_shape above.
strip_wrappers() {
	local leaf="$1"
	local prev=""
	while [[ $leaf != "$prev" ]]; do
		prev=$leaf
		case $leaf in
		# `timeout [opts] DURATION cmd...` -> drop everything up to cmd. We can
		# safely drop the first non-flag, non-numeric-with-suffix token.
		timeout\ *)
			leaf=$(printf '%s' "$leaf" | sed -E 's/^timeout([[:space:]]+(-[A-Za-z0-9_-]+|--[A-Za-z0-9_-]+(=[^[:space:]]+)?))*[[:space:]]+[0-9]+(\.[0-9]+)?[smhd]?[[:space:]]+//')
			;;
		time\ *)
			leaf=${leaf#time }
			;;
		nice\ *)
			leaf=$(printf '%s' "$leaf" | sed -E 's/^nice([[:space:]]+(-[A-Za-z0-9_-]+|--[A-Za-z0-9_-]+(=[^[:space:]]+)?|-n[[:space:]]+-?[0-9]+))*[[:space:]]+//')
			;;
		nohup\ *)
			leaf=${leaf#nohup }
			;;
		stdbuf\ *)
			leaf=$(printf '%s' "$leaf" | sed -E 's/^stdbuf([[:space:]]+-[ioe0L][[:space:]]*[^[:space:]]+)+[[:space:]]+//')
			;;
		# Bare `xargs cmd` (no flags). With flags (`xargs -n1 cmd`) the inner
		# command is opaque to the static matcher anyway, so we leave the
		# wrapper in place and the inner command name will simply not classify.
		xargs\ *)
			local rest="${leaf#xargs }"
			if [[ $rest != -* ]]; then
				leaf="$rest"
			else
				break
			fi
			;;
		*)
			break
			;;
		esac
		leaf=$(printf '%s' "$leaf" | sed -E 's/^[[:space:]]+//')
	done
	printf '%s' "$leaf"
}

# ---------------------------------------------------------------------------
# Per-leaf classification
# ---------------------------------------------------------------------------
#
# Returns via stdout: "safe" if the leaf can be auto-approved on its own merits,
# "uncertain" otherwise. A leaf classified "safe" by command-name OR by the
# help/version rule is acceptable.

classify_leaf() {
	local leaf="$1"

	# Empty leaves arise from trailing operators and trailing newlines; treat
	# as safe (nothing to run).
	if [[ -z $leaf ]]; then
		printf 'safe\n'
		return
	fi

	# Strip env prefix, wrappers, and redirects so we can reason about the
	# command itself.
	leaf=$(strip_env_prefix "$leaf")
	leaf=$(strip_redirects "$leaf")
	leaf=$(strip_wrappers "$leaf")
	leaf=$(printf '%s' "$leaf" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')

	if [[ -z $leaf ]]; then
		printf 'safe\n'
		return
	fi

	# First word is the command name. We want the bare basename, stripped of any
	# path prefix (`/usr/bin/ls` -> `ls`).
	local cmd
	cmd=${leaf%% *}
	cmd=${cmd##*/}

	# Reject leaves whose command contains shell metacharacters that survived
	# decomposition. These are things like glob-expanded command names, or
	# unbalanced quotes; safer to defer.
	if [[ $cmd != [A-Za-z_]* ]]; then
		printf 'uncertain\n'
		return
	fi

	# Help / version rule: if the leaf is `cmd ...flags... (--help|-h|...|version)`
	# and cmd is not on the deny list, treat as safe. We allow flags before the
	# help token because some tools want subcommand context (`gh pr help`).
	local lower_cmd=$cmd
	if _in_list "$lower_cmd" "${DENY_COMMANDS[@]}"; then
		: # falls through; cannot be auto-approved by help/version rule.
	else
		if [[ $leaf =~ ^[A-Za-z][A-Za-z0-9._/+-]*([[:space:]]+([A-Za-z][A-Za-z0-9._:/+-]*|-[A-Za-z]))*[[:space:]]+(--help|-h|--version|-V|help|version)([[:space:]]|$) ]] ||
			[[ $leaf =~ ^[A-Za-z][A-Za-z0-9._/+-]*[[:space:]]+(--help|-h|--version|-V|help|version)([[:space:]]|$) ]]; then
			printf 'safe\n'
			return
		fi
		# Bare `cmd --help` (no extra args) and bare `cmd help` (no subcommand)
		if [[ $leaf =~ ^[A-Za-z][A-Za-z0-9._/+-]*[[:space:]]+(--help|-h|--version|-V|help|version)$ ]]; then
			printf 'safe\n'
			return
		fi
	fi

	# Known-safe read-only command. Match by basename.
	if _in_list "$cmd" "${KNOWN_SAFE_COMMANDS[@]}"; then
		printf 'safe\n'
		return
	fi

	printf 'uncertain\n'
}

_in_list() {
	local needle=$1
	shift
	local item
	for item in "$@"; do
		[[ $item == "$needle" ]] && return 0
	done
	return 1
}

# ---------------------------------------------------------------------------
# Main entry
# ---------------------------------------------------------------------------

main() {
	local input
	input=$(cat)

	local tool_name
	tool_name=$(printf '%s' "$input" | jq -r '.tool_name // ""')

	# We only handle Bash; everything else defers. The hook matcher is set to
	# "Bash" already, but we belt-and-brace.
	if [[ $tool_name != "Bash" ]]; then
		defer
	fi

	local cmd
	cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // ""')

	if [[ -z $cmd ]]; then
		defer
	fi

	# Strip shell comments so a `# rm -rf /` inside a heredoc/string can't be
	# mistaken for a real invocation. Comments are `# ...` to end of line, but
	# only when `#` is at start of token (preceded by whitespace or line start).
	# We use sed across the whole string with multiline mode.
	local cmd_nocomments
	cmd_nocomments=$(printf '%s' "$cmd" | sed -E 's/(^|[[:space:]])#[^\n]*//g')

	# 1. Hard-deny shape detection runs against the full (uncommented) command
	#    line so it sees inside `$(...)`, heredocs, etc.
	hard_deny_shape "$cmd_nocomments"

	# 2. Decompose into leaves and classify each. Also extract command
	#    substitutions and treat their interiors as additional leaves.
	local -a all_leaves=()
	local leaf
	while IFS= read -r leaf; do
		[[ -n $leaf ]] && all_leaves+=("$leaf")
	done < <(split_leaves "$cmd_nocomments")

	# Recurse once into each substitution found in the original command.
	local sub
	while IFS= read -r sub; do
		[[ -z $sub ]] && continue
		while IFS= read -r leaf; do
			[[ -n $leaf ]] && all_leaves+=("$leaf")
		done < <(split_leaves "$sub")
	done < <(extract_substitutions "$cmd_nocomments")

	# No leaves means an empty or whitespace-only command; defer.
	if [[ ${#all_leaves[@]} -eq 0 ]]; then
		defer
	fi

	local verdict
	for leaf in "${all_leaves[@]}"; do
		verdict=$(classify_leaf "$leaf")
		if [[ $verdict != "safe" ]]; then
			defer
		fi
	done

	emit_decision allow "all leaves classified safe by auto-approve hook"
}

main "$@"
