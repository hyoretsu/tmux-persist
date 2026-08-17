#!/usr/bin/env bash
# tmux-continuum cross-compat: persist.tmux exposes a save target under
# continuum's legacy option name, and that target must always save every
# session regardless of what argument continuum passes it (continuum only
# ever sends "quiet", never "all" - see docs/continuum_compat.md).

source "$(dirname "$0")/helpers/test_helpers.sh"
setup

# --- loading the plugin exposes the option, pointed at the wrapper (not save.sh) ---
load_plugin
resurrect_save_path="$(tmuxp show-options -gqv @resurrect-save-script-path)"
assert_eq "$resurrect_save_path" "$PLUGIN_DIR/scripts/continuum_save_compat.sh" \
	"persist.tmux exposes @resurrect-save-script-path, pointed at the wrapper"

# --- the wrapper always saves every session, regardless of its argument ---
make_session one   ONE_MARK
make_session two   TWO_MARK
make_session three THREE_MARK

# continuum always invokes with a bare "quiet" - simulate that call exactly.
tmuxp run-shell "$PLUGIN_DIR/scripts/continuum_save_compat.sh quiet"
sleep 0.6

assert_file "$TEST_PERSIST_DIR/one_last"   "continuum-triggered save wrote session one"
assert_file "$TEST_PERSIST_DIR/two_last"   "continuum-triggered save wrote session two"
assert_file "$TEST_PERSIST_DIR/three_last" "continuum-triggered save wrote session three"

teardown
finish
