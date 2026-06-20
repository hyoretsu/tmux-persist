#!/usr/bin/env bash
# Per-session save/restore: isolation, capture-on-by-default, current-only vs
# all, both snapshot formats, and staging cleanup.

source "$(dirname "$0")/helpers/test_helpers.sh"
setup

# --- capture is on by default + per-session isolation ---
make_session alpha AAA_MARK
make_session beta  BBB_MARK
save alpha
save beta
assert_file "$TEST_PERSIST_DIR/alpha_last" "alpha snapshot created"
assert_file "$TEST_PERSIST_DIR/beta_last"  "beta snapshot created"

tmuxp kill-session -t alpha
tmuxp new-session -d -s alpha
restore alpha
alpha_txt="$(pane_text alpha)"
assert_contains     "$alpha_txt" "AAA_MARK" "alpha restored its own content (capture on by default)"
assert_not_contains "$alpha_txt" "BBB_MARK" "alpha did not get beta's content"

# beta was never recreated/restored by restoring alpha
assert_no_file "$TEST_PERSIST_DIR/save"    "save staging removed"
assert_no_file "$TEST_PERSIST_DIR/restore" "restore staging removed"

# --- manual save targets only the given session ---
make_session gamma GGG_MARK
save gamma
tmuxp new-session -d -s delta            # never saved
assert_file    "$TEST_PERSIST_DIR/gamma_last" "save wrote the requested session"
assert_no_file "$TEST_PERSIST_DIR/delta_last" "save did not touch other sessions"

# --- save all (used by the on-exit hooks) ---
make_session one ONE_MARK
make_session two TWO_MARK
save all
assert_file "$TEST_PERSIST_DIR/one_last" "save all wrote session one"
assert_file "$TEST_PERSIST_DIR/two_last" "save all wrote session two"

# --- snapshot formats round-trip ---
for fmt in together separate; do
	tmuxp set -g @persist-snapshot-format "$fmt"
	make_session "fmt_$fmt" "FMT_${fmt}_MARK"
	save "fmt_$fmt"
	if [ "$fmt" = "together" ]; then
		assert_file "$(echo "$TEST_PERSIST_DIR/fmt_${fmt}_"*.tgz)" "together: single .tgz snapshot"
	else
		assert_file "$(echo "$TEST_PERSIST_DIR/fmt_${fmt}_"*[0-9].txt)" "separate: .txt layout"
		assert_file "$(echo "$TEST_PERSIST_DIR/fmt_${fmt}_"*_pane_contents.tgz)" "separate: pane-contents companion"
	fi
	tmuxp kill-session -t "fmt_$fmt"
	tmuxp new-session -d -s "fmt_$fmt"
	restore "fmt_$fmt"
	assert_contains "$(pane_text "fmt_$fmt")" "FMT_${fmt}_MARK" "$fmt snapshot restored content"
done

teardown
finish
