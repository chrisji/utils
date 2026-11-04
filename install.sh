#!/bin/bash
# Symlink the scripts in scripts/ into a bin directory (default ~/.local/bin).
set -euo pipefail

USAGE="usage: install.sh [--bin-dir DIR] [--dry-run] [--force] [NAME ...]"
# shellcheck source=lib/common.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

parse_args 1 "$@"

if [ ${#NAMES[@]} -eq 0 ]; then
	while IFS= read -r name; do NAMES+=("$name"); done < <(all_script_names)
else
	for name in "${NAMES[@]}"; do
		[ -f "$SCRIPTS_DIR/$name" ] || die_usage "no such script: $name"
	done
fi

if [ ! -d "$BIN_DIR" ]; then
	say "create" "$BIN_DIR"
	run mkdir -p "$BIN_DIR"
fi

status=0
for name in ${NAMES[@]+"${NAMES[@]}"}; do
	src="$SCRIPTS_DIR/$name"
	dest="$BIN_DIR/$name"

	[ -x "$src" ] || warn "warning: $src is not executable (git update-index --chmod=+x scripts/$name)"

	if [ -L "$dest" ] && [ "$(readlink "$dest")" = "$src" ]; then
		say "already installed" "$name"
	elif is_ours "$dest"; then
		run ln -sfn "$src" "$dest"
		say "relinked" "$name"
	elif [ -e "$dest" ] || [ -L "$dest" ]; then
		if [ "$FORCE" = 1 ]; then
			backup="$dest.bak.$(date +%Y%m%d%H%M%S)"
			if [ -e "$backup" ] || [ -L "$backup" ]; then
				warn "skipped $name: backup $backup already exists"
				status=1
				continue
			fi
			run mv "$dest" "$backup"
			run ln -s "$src" "$dest"
			say "installed" "$name" "moved existing file to $backup"
		else
			warn "skipped $name: $dest exists (use --force to back it up and replace it)"
			status=1
		fi
	else
		run ln -s "$src" "$dest"
		say "installed" "$name"
	fi
done

case ":$PATH:" in
	*":$BIN_DIR:"*) ;;
	*)
		warn "warning: $BIN_DIR is not on your PATH. Add this to ~/.zshrc:"
		warn "  export PATH=\"$BIN_DIR:\$PATH\""
		;;
esac

exit $status
