# Utils
Collection of scripts for various tasks

## Installing
```
git clone https://github.com/chrisji/utils.git
cd utils
./install.sh                 # all scripts, or: ./install.sh del
```

Each script in `scripts/` is symlinked into `~/.local/bin` (change with
`--bin-dir DIR` or `BIN_DIR=...`), so edits and `git pull` take effect
immediately. No `sudo` needed. Existing files are never overwritten; `--force`
moves them aside to `<name>.bak.<timestamp>` first. `--dry-run` shows what
would happen.

## Uninstalling
```
./uninstall.sh               # all, or: ./uninstall.sh del
```

Only removes symlinks that point into this repo's `scripts/`. Run it before
moving or deleting the clone.

## Tests
```
tests/test-install.sh
```
