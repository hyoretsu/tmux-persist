#!/usr/bin/env bash
# Saved sessions are application state, so a fresh install should default to
# $XDG_STATE_HOME/tmux/persist. Existing locations must still be honoured so no
# one's snapshots move. (tmux-resurrect#542)

source "$(dirname "$0")/helpers/test_helpers.sh"
setup

# Resolve default_persist_dir under a controlled HOME/XDG environment.
resolve_dir() { # extra-env-setup-snippet
	local out="$TEST_PERSIST_DIR/dir.out"
	rm -f "$out"
	tmuxp run-shell "bash -c 'export HOME=\"$1\"; $2 \
		source \"$PLUGIN_DIR/scripts/variables.sh\"; \
		source \"$PLUGIN_DIR/scripts/helpers.sh\"; \
		printf %s \"\$default_persist_dir\" > \"$out\"'"
	sleep 0.4
	cat "$out"
}

home="$TEST_PERSIST_DIR/home"
mkdir -p "$home"

# Fresh install, XDG_STATE_HOME set -> state dir.
assert_eq "$(resolve_dir "$home" "export XDG_STATE_HOME=$home/.local/state; unset XDG_DATA_HOME;")" \
	"$home/.local/state/tmux/persist" "fresh install defaults to XDG_STATE_HOME"

# Fresh install, XDG_STATE_HOME unset -> ~/.local/state default.
assert_eq "$(resolve_dir "$home" "unset XDG_STATE_HOME; unset XDG_DATA_HOME;")" \
	"$home/.local/state/tmux/persist" "fresh install falls back to ~/.local/state"

# Existing data-dir install keeps working (no forced migration).
mkdir -p "$home/.local/share/tmux/persist"
assert_eq "$(resolve_dir "$home" "unset XDG_STATE_HOME; unset XDG_DATA_HOME;")" \
	"$home/.local/share/tmux/persist" "existing data-dir install is still used"

# Legacy ~/.tmux/resurrect still wins when present.
mkdir -p "$home/.tmux/resurrect"
assert_eq "$(resolve_dir "$home" "unset XDG_STATE_HOME; unset XDG_DATA_HOME;")" \
	"$home/.tmux/resurrect" "legacy ~/.tmux/resurrect still honoured"

teardown
finish
