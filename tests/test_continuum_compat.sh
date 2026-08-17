#!/usr/bin/env bash
# tmux-continuum cross-compat: persist.tmux exposes save/restore targets
# under continuum's legacy option names, and both must always act on every
# session regardless of what argument (if any) continuum passes them -
# continuum's save trigger only ever sends "quiet", never "all"; its
# restore trigger sends no arguments at all (see docs/continuum_compat.md).

source "$(dirname "$0")/helpers/test_helpers.sh"
setup

# --- loading the plugin exposes both options, pointed at their wrappers ---
load_plugin
resurrect_save_path="$(tmuxp show-options -gqv @resurrect-save-script-path)"
assert_eq "$resurrect_save_path" "$PLUGIN_DIR/scripts/continuum_save_compat.sh" \
	"persist.tmux exposes @resurrect-save-script-path, pointed at the wrapper"
resurrect_restore_path="$(tmuxp show-options -gqv @resurrect-restore-script-path)"
assert_eq "$resurrect_restore_path" "$PLUGIN_DIR/scripts/continuum_restore_compat.sh" \
	"persist.tmux exposes @resurrect-restore-script-path, pointed at the wrapper"

# --- the save wrapper always saves every session, regardless of its argument ---
make_session one   ONE_MARK
make_session two   TWO_MARK
make_session three THREE_MARK

# continuum always invokes with a bare "quiet" - simulate that call exactly.
tmuxp run-shell "$PLUGIN_DIR/scripts/continuum_save_compat.sh quiet"
sleep 0.6

assert_file "$TEST_PERSIST_DIR/one_last"   "continuum-triggered save wrote session one"
assert_file "$TEST_PERSIST_DIR/two_last"   "continuum-triggered save wrote session two"
assert_file "$TEST_PERSIST_DIR/three_last" "continuum-triggered save wrote session three"

# --- the restore wrapper always restores every saved session, with no
# arguments at all, matching exactly how continuum's boot-time restore
# invokes it (no session name, no "all" - just the bare script path).
tmuxp kill-session -t one
tmuxp kill-session -t two
tmuxp kill-session -t three

tmuxp run-shell "$PLUGIN_DIR/scripts/continuum_restore_compat.sh"

# Poll rather than a fixed sleep: pane-content-restore for 3 sequential
# sessions has enough timing variance under load that a fixed sleep here
# was observed flaky (whichever session happened to still be mid-restore
# when the sleep ended intermittently failed - not always the same one).
poll_until 10 sh -c "tmux -L '$TEST_SOCKET' capture-pane -pt one   -S -200 2>/dev/null | grep -q ONE_MARK"
poll_until 10 sh -c "tmux -L '$TEST_SOCKET' capture-pane -pt two   -S -200 2>/dev/null | grep -q TWO_MARK"
poll_until 10 sh -c "tmux -L '$TEST_SOCKET' capture-pane -pt three -S -200 2>/dev/null | grep -q THREE_MARK"

assert_contains "$(pane_text one)"   "ONE_MARK"   "continuum-triggered restore recreated session one"
assert_contains "$(pane_text two)"   "TWO_MARK"   "continuum-triggered restore recreated session two"
assert_contains "$(pane_text three)" "THREE_MARK" "continuum-triggered restore recreated session three"

# --- reloading the plugin must not mistake either of its own
# @resurrect-*-script-path options for a user-set legacy option and fire a
# false "deprecated options" warning. These are the only @resurrect-*
# options persist.tmux itself ever sets, so a naive "any @resurrect-*
# option present" check would start matching them from the plugin's second
# load onward (the first load runs this check before setting them) - for
# every user, continuum or not. Worse: since the warning is gated by a
# one-shot flag, a false trigger here would also permanently suppress the
# real warning for anyone who later sets an actual legacy option. (The
# other half of this regression check - that a genuine legacy option still
# triggers the warning correctly - is already covered by
# test_legacy_compat.sh; no need to duplicate it here.)
load_plugin
load_plugin
assert_eq "$(tmuxp show-options -gqv @persist-legacy-warned)" "" \
	"reloading twice with no user legacy options sets no false warning flag"

teardown
finish
