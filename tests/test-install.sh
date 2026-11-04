#!/bin/bash
# Tests for install.sh and uninstall.sh. Every case runs against a temporary
# BIN_DIR, never the real ~/.local/bin.
set -uo pipefail

SOURCE_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)

TMP_ROOT=$(mktemp -d)
trap 'rm -rf "$TMP_ROOT"' EXIT

# make_repo DIR - a copy of the installer with two fake scripts, so the tests
# don't depend on which real scripts exist.
make_repo() {
	mkdir -p "$1/scripts"
	cp -R "$SOURCE_DIR/install.sh" "$SOURCE_DIR/uninstall.sh" "$SOURCE_DIR/lib" "$1/"
	printf '#!/bin/sh\necho alpha\n' > "$1/scripts/alpha"
	printf '#!/bin/sh\necho beta\n' > "$1/scripts/beta"
	chmod +x "$1/scripts/alpha" "$1/scripts/beta"
}

make_repo "$TMP_ROOT/repo"
REPO_DIR=$(cd "$TMP_ROOT/repo" && pwd -P)
INSTALL="$REPO_DIR/install.sh"
UNINSTALL="$REPO_DIR/uninstall.sh"

failures=0
passes=0

fail() { echo "  FAIL: $*"; failures=$((failures + 1)); }
pass() { passes=$((passes + 1)); }
check() { if eval "$1"; then pass; else fail "$2"; fi; }

new_bin() { mktemp -d "$TMP_ROOT/bin.XXXXXX"; }

# Name, type, link target and checksum of every entry - enough to tell
# whether a directory changed.
snapshot() {
	local entry
	for entry in "$1"/* "$1"/.[!.]*; do
		[ -e "$entry" ] || [ -L "$entry" ] || continue
		if [ -L "$entry" ]; then
			echo "L $(basename "$entry") -> $(readlink "$entry")"
		else
			echo "F $(basename "$entry") $(cksum < "$entry")"
		fi
	done
}

script_names() {
	local f
	for f in "$1"/scripts/*; do [ -f "$f" ] && basename "$f"; done
	return 0
}

echo "1. install into an empty dir"
bin=$(new_bin)
"$INSTALL" --bin-dir "$bin" >/dev/null 2>&1
check '[ $? -eq 0 ]' "install exited non-zero"
for name in $(script_names "$REPO_DIR"); do
	check '[ "$(readlink "$bin/$name")" = "$REPO_DIR/scripts/$name" ]' "$name not linked to repo"
	check '[ -x "$bin/$name" ]' "$name not executable through link"
done

echo "2. install twice is idempotent"
out=$("$INSTALL" --bin-dir "$bin" 2>/dev/null)
check '[ $? -eq 0 ]' "second install exited non-zero"
check '! grep -qv "^already installed " <<<"$out"' "second install did something: $out"

echo "3. existing regular file is skipped"
bin=$(new_bin)
echo "precious" > "$bin/alpha"
"$INSTALL" --bin-dir "$bin" >/dev/null 2>&1
check '[ $? -eq 1 ]' "expected exit 1 when skipping"
check '[ ! -L "$bin/alpha" ] && [ "$(cat "$bin/alpha")" = precious ]' "existing file was touched"
check '[ -L "$bin/beta" ]' "other scripts not installed"

echo "4. --force backs up and replaces"
"$INSTALL" --bin-dir "$bin" --force >/dev/null 2>&1
check '[ $? -eq 0 ]' "--force exited non-zero"
check '[ -L "$bin/alpha" ]' "alpha not linked after --force"
backups=("$bin"/alpha.bak.*)
check '[ -f "${backups[0]}" ] && [ "$(cat "${backups[0]}")" = precious ]' "backup missing or wrong"

echo "5. foreign symlink is skipped"
bin=$(new_bin)
ln -s /usr/bin/true "$bin/alpha"
"$INSTALL" --bin-dir "$bin" >/dev/null 2>&1
check '[ $? -eq 1 ]' "expected exit 1 when skipping"
check '[ "$(readlink "$bin/alpha")" = /usr/bin/true ]' "foreign link was changed"

echo "6. uninstall restores the original state"
bin=$(new_bin)
echo "x" > "$bin/unrelated"
before=$(snapshot "$bin")
"$INSTALL" --bin-dir "$bin" >/dev/null 2>&1
"$UNINSTALL" --bin-dir "$bin" >/dev/null 2>&1
check '[ $? -eq 0 ]' "uninstall exited non-zero"
check '[ "$(snapshot "$bin")" = "$before" ]' "dir differs after install+uninstall"

echo "7. uninstall leaves foreign files, foreign links and backups"
bin=$(new_bin)
echo "precious" > "$bin/alpha"
ln -s /usr/bin/true "$bin/beta"
"$INSTALL" --bin-dir "$bin" --force >/dev/null 2>&1
ln -s /usr/bin/true "$bin/other-link"
echo "y" > "$bin/other-file"
"$UNINSTALL" --bin-dir "$bin" >/dev/null 2>&1
check '[ ! -e "$bin/alpha" ] && [ ! -L "$bin/alpha" ]' "our alpha link not removed"
check '[ "$(readlink "$bin/other-link")" = /usr/bin/true ]' "foreign link removed"
check '[ -f "$bin/other-file" ]' "foreign file removed"
check 'ls "$bin"/alpha.bak.* >/dev/null 2>&1' "backup removed"

echo "8. uninstall removes dangling links into the repo"
bin=$(new_bin)
ln -s "$REPO_DIR/scripts/no-longer-exists" "$bin/no-longer-exists"
"$UNINSTALL" --bin-dir "$bin" >/dev/null 2>&1
check '[ ! -L "$bin/no-longer-exists" ]' "dangling link not removed"

echo "9. --dry-run changes nothing"
bin=$(new_bin)
echo "precious" > "$bin/alpha"
before=$(snapshot "$bin")
"$INSTALL" --bin-dir "$bin" --dry-run --force >/dev/null 2>&1
check '[ "$(snapshot "$bin")" = "$before" ]' "install --dry-run changed the dir"
"$INSTALL" --bin-dir "$bin" --force >/dev/null 2>&1
before=$(snapshot "$bin")
"$UNINSTALL" --bin-dir "$bin" --dry-run >/dev/null 2>&1
check '[ "$(snapshot "$bin")" = "$before" ]' "uninstall --dry-run changed the dir"
missing="$TMP_ROOT/not-created"
"$INSTALL" --bin-dir "$missing" --dry-run >/dev/null 2>&1
check '[ ! -e "$missing" ]' "install --dry-run created the bin dir"

echo "10. repo path containing a space"
clone="$TMP_ROOT/my utils"
make_repo "$clone"
clone=$(cd "$clone" && pwd -P)
bin="$TMP_ROOT/bin dir"
(cd / && "$clone/install.sh" --bin-dir "$bin" >/dev/null 2>&1)
check '[ $? -eq 0 ]' "install from spaced path exited non-zero"
check '[ "$(readlink "$bin/alpha")" = "$clone/scripts/alpha" ]' "link wrong for spaced path"
(cd / && "$clone/uninstall.sh" --bin-dir "$bin" >/dev/null 2>&1)
check '[ -z "$(snapshot "$bin")" ]' "uninstall from spaced path left entries"

echo "11. other checks"
"$INSTALL" --bin-dir "$(new_bin)" no-such-script >/dev/null 2>&1
check '[ $? -eq 2 ]' "unknown script name should exit 2"
"$UNINSTALL" --force >/dev/null 2>&1
check '[ $? -eq 2 ]' "uninstall --force should be a usage error"
bin=$(new_bin)
BIN_DIR="$bin" "$INSTALL" alpha >/dev/null 2>&1
check '[ -L "$bin/alpha" ] && [ ! -e "$bin/beta" ]' "BIN_DIR env var / single name install"

echo
echo "$passes passed, $failures failed"
[ "$failures" -eq 0 ]
