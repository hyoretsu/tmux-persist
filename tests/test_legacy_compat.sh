#!/usr/bin/env bash
# Backward compatibility with tmux-resurrect: old @resurrect-* options and the
# legacy save directory keep working, with a one-time deprecation notice.

source "$(dirname "$0")/helpers/test_helpers.sh"
setup

# Switch to a legacy-style config: no @persist-* options, only @resurrect-*.
tmuxp set -gu @persist-dir
tmuxp set -g @resurrect-dir "$TEST_PERSIST_DIR"

# --- legacy @resurrect-dir honored for save + restore ---
make_session legacy LEGACY_MARK
save legacy
assert_file "$TEST_PERSIST_DIR/legacy_last" "legacy @resurrect-dir used for saving"

tmuxp kill-session -t legacy
tmuxp new-session -d -s legacy
restore legacy
assert_contains "$(pane_text legacy)" "LEGACY_MARK" "restore works under legacy @resurrect-dir"

# --- legacy @resurrect-capture-pane-contents honored ---
tmuxp set -g @resurrect-capture-pane-contents off
make_session nocap NOCAP_MARK
save nocap
snap="$(echo "$TEST_PERSIST_DIR/nocap_"*.tgz)"
assert_not_contains "$(tar tzf "$snap" 2>/dev/null)" "pane_contents" \
	"legacy @resurrect-capture-pane-contents 'off' honored"
tmuxp set -g @resurrect-capture-pane-contents on

# --- one-time deprecation notice when legacy options are present ---
load_plugin
assert_eq "$(tmuxp show-option -gqv @persist-legacy-warned)" "1" \
	"legacy @resurrect-* options set the one-time deprecation marker"

teardown
finish
