#!/bin/bash
# Remove the symlinks install.sh created. Only ever removes symlinks that
# point into this repo's scripts/ directory.
set -euo pipefail

USAGE="usage: uninstall.sh [--bin-dir DIR] [--dry-run] [NAME ...]"
# shellcheck source=lib/common.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

parse_args 0 "$@"

if [ ! -d "$BIN_DIR" ]; then
	echo "nothing to do: $BIN_DIR does not exist"
	exit 0
fi

if [ ${#NAMES[@]} -eq 0 ]; then
	# Scan the whole bin dir, so links to scripts since removed from the repo
	# are cleaned up too.
	for entry in "$BIN_DIR"/*; do
		if is_ours "$entry"; then
			run rm "$entry"
			say "removed" "$(basename "$entry")"
		fi
	done
else
	for name in "${NAMES[@]}"; do
		if is_ours "$BIN_DIR/$name"; then
			run rm "$BIN_DIR/$name"
			say "removed" "$name"
		else
			echo "not installed $name"
		fi
	done
fi

# Backups made by install.sh --force are left for the user to restore.
while IFS= read -r name; do
	for backup in "$BIN_DIR/$name".bak.*; do
		[ -e "$backup" ] || [ -L "$backup" ] || continue
		warn "note: backup left in place: $backup"
	done
done < <(all_script_names)
