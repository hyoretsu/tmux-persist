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

# --- reloading the plugin must not mistake its own @resurrect-save-script-path
# for a user-set legacy option and fire a false "deprecated options" warning.
# It's the only @resurrect-* option persist.tmux itself ever sets, so a naive
# "any @resurrect-* option present" check would start matching itself from
# the plugin's second load onward (the first load runs this check before
# setting the option) - for every user, continuum or not. Worse: since the
# warning is gated by a one-shot flag, a false trigger here would also
# permanently suppress the real warning for anyone who later sets an actual
# legacy option. (The other half of this regression check - that a genuine
# legacy option still triggers the warning correctly - is already covered by
# test_legacy_compat.sh; no need to duplicate it here.)
load_plugin
load_plugin
assert_eq "$(tmuxp show-options -gqv @persist-legacy-warned)" "" \
	"reloading twice with no user legacy options sets no false warning flag"

teardown
finish
