# Shared helpers for install.sh and uninstall.sh. Sourced, not executed.
# Must stay compatible with macOS's /bin/bash 3.2.

REPO_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
SCRIPTS_DIR="$REPO_DIR/scripts"

DRY_RUN=0
FORCE=0
NAMES=()

warn() { echo "$*" >&2; }

die_usage() {
	warn "$1"
	warn "$USAGE"
	exit 2
}

# parse_args ALLOW_FORCE "$@" - sets BIN_DIR, DRY_RUN, FORCE and NAMES.
parse_args() {
	local allow_force=$1
	shift
	local bin_dir_flag=""
	while [ $# -gt 0 ]; do
		case $1 in
			--bin-dir)
				[ $# -ge 2 ] || die_usage "--bin-dir needs a directory"
				bin_dir_flag=$2
				shift 2
				;;
			--bin-dir=*) bin_dir_flag=${1#--bin-dir=}; shift ;;
			--dry-run) DRY_RUN=1; shift ;;
			--force)
				[ "$allow_force" = 1 ] || die_usage "unknown option: $1"
				FORCE=1
				shift
				;;
			-h|--help) echo "$USAGE"; exit 0 ;;
			--) shift; NAMES+=("$@"); break ;;
			-*) die_usage "unknown option: $1" ;;
			*) NAMES+=("$1"); shift ;;
		esac
	done
	BIN_DIR=${bin_dir_flag:-${BIN_DIR:-$HOME/.local/bin}}
	BIN_DIR=${BIN_DIR%/}
}

# The scripts in scripts/, one name per line.
all_script_names() {
	local f
	for f in "$SCRIPTS_DIR"/*; do
		[ -f "$f" ] && basename "$f"
	done
}

# True if PATH is a symlink whose target lies inside this repo's scripts/.
# Checks the target as a string, so dangling links count too.
is_ours() {
	[ -L "$1" ] || return 1
	case $(readlink "$1") in
		"$SCRIPTS_DIR"/*) return 0 ;;
		*) return 1 ;;
	esac
}

# run CMD... - runs CMD, or does nothing under --dry-run.
run() {
	[ "$DRY_RUN" = 1 ] || "$@"
}

# say ACTION NAME [DETAIL] - one line of output per script.
say() {
	local prefix=""
	[ "$DRY_RUN" = 1 ] && prefix="would "
	echo "${prefix}$1 $2${3:+: $3}"
}
