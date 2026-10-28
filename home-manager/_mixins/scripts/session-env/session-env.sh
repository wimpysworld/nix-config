#!/usr/bin/env bash
set -euo pipefail

# The Nix wrapper sets the positional parameters to the allow list, then the
# user arguments, separated by "--".
allowed=()
while (($#)) && [[ "$1" != -- ]]; do
    allowed+=("$1")
    shift
done
if (($#)); then
    shift
fi

format=posix
case "${1:-}" in
"") ;;
--fish) format=fish ;;
-h | --help)
    cat <<'EOF'
Usage: session-env [--fish]

Print shell assignments for the graphical session variables of the systemd
user manager. Evaluate the output to repair a shell that has no display.

  bash:  eval "$(session-env)"
  fish:  session-env --fish | source

The output is empty when the user manager has no graphical session.
EOF
    exit 0
    ;;
*)
    echo "session-env: unsupported argument: $1" >&2
    exit 2
    ;;
esac

# systemctl prints a value that holds special characters in the $'...' form.
# This decodes that form without eval into "decoded".
decode() {
    local value="$1" out='' char next code
    if [[ "$value" != "\$'"*"'" ]]; then
        decoded=$value
        return
    fi
    value=${value:2:${#value}-3}
    while [[ -n "$value" ]]; do
        char=${value:0:1}
        value=${value:1}
        if [[ "$char" != "\\" || -z "$value" ]]; then
            out+=$char
            continue
        fi
        next=${value:0:1}
        value=${value:1}
        case "$next" in
        a) out+=$'\a' ;;
        b) out+=$'\b' ;;
        e) out+=$'\e' ;;
        f) out+=$'\f' ;;
        n) out+=$'\n' ;;
        r) out+=$'\r' ;;
        t) out+=$'\t' ;;
        v) out+=$'\v' ;;
        x)
            code=${value:0:2}
            code=${code%%[!0-9a-fA-F]*}
            value=${value:${#code}}
            if [[ -n "$code" ]]; then
                printf -v char '%b' "\\x${code}"
                out+=$char
            else
                out+='\x'
            fi
            ;;
        [0-7])
            code=$next${value:0:2}
            code=${code%%[!0-7]*}
            value=${value:${#code}-1}
            printf -v char '%b' "\\0${code}"
            out+=$char
            ;;
        *) out+=$next ;;
        esac
    done
    decoded=$out
}

command -v systemctl >/dev/null 2>&1 || exit 0
environment=$(systemctl --user show-environment 2>/dev/null) || exit 0

declare -A found=()
while IFS= read -r line; do
    name=${line%%=*}
    [[ "$name" != "$line" ]] || continue
    for wanted in "${allowed[@]}"; do
        if [[ "$name" == "$wanted" ]]; then
            decode "${line#*=}"
            found[$name]=$decoded
            break
        fi
    done
done <<<"$environment"

# Without a Wayland or X11 display, the manager has no graphical session.
[[ -n "${found[WAYLAND_DISPLAY]:-}" || -n "${found[DISPLAY]:-}" ]] || exit 0

# Single quotes keep every value literal. Fish also treats a backslash as an
# escape inside single quotes, so its form escapes backslashes too.
for name in "${allowed[@]}"; do
    [[ -n "${found[$name]+set}" ]] || continue
    value=${found[$name]}
    if [[ "$format" == fish ]]; then
        value=${value//\\/\\\\}
        printf "set -gx %s '%s'\n" "$name" "${value//\'/\\\'}"
    else
        printf "export %s='%s'\n" "$name" "${value//\'/\'\\\'\'}"
    fi
done
