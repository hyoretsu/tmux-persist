#!/usr/bin/env bash
# Snapshot retention: age window, max-snapshots cap, full expiry of stale
# sessions, the "a" vs "a_b" collision, and pane-contents companion removal.

source "$(dirname "$0")/helpers/test_helpers.sh"
setup

snap() { # session timestamp [days_ago]
	local f="$TEST_PERSIST_DIR/${1}_${2}.tgz"
	: > "$f"
	[ -n "$3" ] && touch -d "$3 days ago" "$f"
}

# --- age window: old snapshot removed, newest kept (default 7 days) ---
snap aged 20260601T120000 12      # old
snap aged 20260620T120000          # recent
ln -sf "aged_20260620T120000.tgz" "$TEST_PERSIST_DIR/aged_last"
prune
assert_no_file "$TEST_PERSIST_DIR/aged_20260601T120000.tgz" "age: old snapshot erased"
assert_file    "$TEST_PERSIST_DIR/aged_20260620T120000.tgz" "age: recent snapshot kept"
assert_file    "$TEST_PERSIST_DIR/aged_last"                "age: last pointer kept"

# --- full expiry: every snapshot too old -> last pointer dropped too ---
snap stale 20260601T120000 30
ln -sf "stale_20260601T120000.tgz" "$TEST_PERSIST_DIR/stale_last"
prune
assert_no_file "$TEST_PERSIST_DIR/stale_20260601T120000.tgz" "expiry: stale snapshot erased"
assert_no_file "$TEST_PERSIST_DIR/stale_last"                "expiry: dangling last pointer removed"

# --- collision: pruning "a" must not affect "a_b" ---
snap a   20260601T120000 30        # a is fully stale
ln -sf "a_20260601T120000.tgz" "$TEST_PERSIST_DIR/a_last"
snap a_b 20260620T120000           # a_b is fresh
ln -sf "a_b_20260620T120000.tgz" "$TEST_PERSIST_DIR/a_b_last"
prune
assert_no_file "$TEST_PERSIST_DIR/a_20260601T120000.tgz"   "collision: a erased"
assert_file    "$TEST_PERSIST_DIR/a_b_20260620T120000.tgz" "collision: a_b untouched by pruning a"
assert_file    "$TEST_PERSIST_DIR/a_b_last"                "collision: a_b last pointer kept"

# --- max-snapshots cap: keep only the newest N (all recent) ---
for ts in 20260613 20260614 20260615 20260616 20260617 20260618 20260619 20260620; do
	snap capped "${ts}T120000"
done
ln -sf "capped_20260620T120000.tgz" "$TEST_PERSIST_DIR/capped_last"
tmuxp set -g @persist-max-snapshots 3
prune
kept="$(ls "$TEST_PERSIST_DIR"/capped_*T*.tgz 2>/dev/null | wc -l | tr -d ' ')"
assert_eq "$kept" "3" "cap: only newest 3 snapshots kept"
assert_file "$TEST_PERSIST_DIR/capped_20260620T120000.tgz" "cap: newest kept"
assert_no_file "$TEST_PERSIST_DIR/capped_20260613T120000.tgz" "cap: oldest removed"
tmuxp set -g @persist-max-snapshots 0

# --- separate format: companion removed with its primary ---
sep() { # timestamp
	: > "$TEST_PERSIST_DIR/proj_${1}.txt"
	: > "$TEST_PERSIST_DIR/proj_${1}_pane_contents.tgz"
}
sep 20260619T120000
sep 20260620T120000
ln -sf "proj_20260620T120000.txt" "$TEST_PERSIST_DIR/proj_last"
tmuxp set -g @persist-max-snapshots 1
prune
assert_no_file "$TEST_PERSIST_DIR/proj_20260619T120000.txt"               "companion: old layout removed"
assert_no_file "$TEST_PERSIST_DIR/proj_20260619T120000_pane_contents.tgz" "companion: old pane-contents removed"
assert_file    "$TEST_PERSIST_DIR/proj_20260620T120000.txt"               "companion: newest layout kept"
assert_file    "$TEST_PERSIST_DIR/proj_20260620T120000_pane_contents.tgz" "companion: newest pane-contents kept"

teardown
finish
