#!/usr/bin/env bash
# Session names containing "/" (a real, not just synthetic, naming pattern -
# e.g. an org/repo-derived name) must not be interpolated raw into a
# persist-dir filename: the "/" would be read as a directory separator and
# save/restore/prune would silently fail or target the wrong file. Also
# covers the encoding's collision case: a session literally containing the
# escape sequence used for "/" must not collide with an actual "/" session.

source "$(dirname "$0")/helpers/test_helpers.sh"
setup

# --- save + restore round trip for a session name containing "/" ---
make_session "team/project" SLASH_MARK
save "team/project"
assert_file "$TEST_PERSIST_DIR/team%2Fproject_last" "slash session: sanitized snapshot created"

tmuxp kill-session -t "team/project"
tmuxp new-session -d -s "team/project"
restore "team/project"
slash_txt="$(pane_text "team/project")"
assert_contains "$slash_txt" "SLASH_MARK" "slash session: restored its own content"

# --- collision: "a/b" and "a%2Fb" must not share a snapshot ---
make_session "a/b"   A_SLASH_B_MARK
make_session "a%2Fb" A_PCT_2F_B_MARK
save "a/b"
save "a%2Fb"
assert_file "$TEST_PERSIST_DIR/a%2Fb_last"    "collision: a/b sanitized snapshot created"
assert_file "$TEST_PERSIST_DIR/a%252Fb_last"  "collision: a%2Fb sanitized snapshot created (not the same file)"

tmuxp kill-session -t "a/b"
tmuxp new-session -d -s "a/b"
restore "a/b"
a_slash_b_txt="$(pane_text "a/b")"
assert_contains     "$a_slash_b_txt" "A_SLASH_B_MARK"   "collision: a/b restored its own content"
assert_not_contains "$a_slash_b_txt" "A_PCT_2F_B_MARK"  "collision: a/b did not get a%2Fb's content"

# --- pruning round-trips a slash session name without erroring or misfiring ---
# (exercises _unsanitize_session_from_path: prune_all_old_backups() only has
# the already-sanitized "_last" filename to work with, and must recover the
# real session name before calling remove_old_backups(), which re-sanitizes.)
prune
assert_file "$TEST_PERSIST_DIR/team%2Fproject_last" "slash session: survives pruning (fresh, not stale)"
assert_file "$TEST_PERSIST_DIR/a%2Fb_last"           "collision: a/b survives pruning"
assert_file "$TEST_PERSIST_DIR/a%252Fb_last"         "collision: a%2Fb survives pruning"

teardown
finish
