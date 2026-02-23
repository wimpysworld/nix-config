#!/usr/bin/env bash

# Determine whether a NixOS system needs rebooting after activation.
# Compares the booted system against the current (or specified) profile
# for changes to kernel, kernel-modules, and initrd.

set +e          # Disable errexit - we handle exit codes explicitly
set +u          # Disable nounset
set +o pipefail # Disable pipefail

# Resolve a path to its canonical target, even if it is not a symlink.
resolve_link() {
	canonical="$(readlink -m "$1")"
	if [ -n "$canonical" ]; then
		echo "$canonical"
	else
		echo "$1"
	fi
}

# The systems to compare.
booted="$(resolve_link /run/booted-system)"
if [ "$#" -ge "1" ]; then
	built="$(resolve_link "$1")"
else
	built="$(resolve_link /nix/var/nix/profiles/system)"
fi

# Extract the derivation name from a Nix store path.
strip_store_path() {
	path="$1"
	path="${path#/nix/store/*-}"
	path="${path%%/*}"
	echo "$path"
}

# Compare a component between the booted and built systems.
# Prints the version change if the component differs.
compare_component() {
	a="$(resolve_link "$booted/$1")"
	b="$(resolve_link "$built/$1")"
	if [ "$a" != "$b" ]; then
		echo "  $(strip_store_path "$a") -> $(strip_store_path "$b")"
	fi
}

changes=""

for component in "kernel" "kernel-modules" "initrd"; do
	out="$(compare_component "$component")"
	if [ -n "$out" ]; then
		changes="${changes}${out}\n"
	fi
done

if [ -z "$changes" ]; then
	echo "Reboot  not required"
	exit 2
else
	echo -e "Reboot \e[1madvised\e[0m - kernel/initrd changed:"
	echo -e "$changes"
	exit 0
fi
