#!/usr/bin/env bash
# Direct unit test of touch_days_ago's date math (tests/helpers/test_helpers.sh),
# isolated from tmux entirely. test_pruning.sh/test_skip_unchanged.sh already
# exercise this indirectly, but only with wide margins (12 vs 7 days, 30 vs 7
# days) that wouldn't catch a subtle off-by-one - this asserts the actual
# computed mtime directly, with a tight tolerance.

source "$(dirname "$0")/helpers/test_helpers.sh"

WORKDIR="$(mktemp -d "${TMPDIR:-/tmp}/touch-days-ago-test.XXXXXX")"

now_epoch() { date +%s; }
mtime_epoch() { stat -f '%m' "$1" 2>/dev/null || stat -c '%Y' "$1"; }

assert_close_to_now_minus() { # days file label
	local days="$1" file="$2" label="$3"
	local delta=$(( $(now_epoch) - (days * 86400) - $(mtime_epoch "$file") ))
	[ "$delta" -lt 0 ] && delta=$((-delta))
	# 2 minutes of slack for test execution time; an off-by-one bug would be
	# off by a full day (86400s), so this margin is tight enough to catch one.
	if [ "$delta" -le 120 ]; then
		_ok "$label"
	else
		_ko "$label (off by ${delta}s)"
	fi
}

# --- 0, 1, and 30 days ago each land within 2 minutes of the true target ---
f="$WORKDIR/zero"; : > "$f"; touch_days_ago 0 "$f"
assert_close_to_now_minus 0 "$f" "0 days ago: mtime matches now"

f="$WORKDIR/one"; : > "$f"; touch_days_ago 1 "$f"
assert_close_to_now_minus 1 "$f" "1 day ago: mtime matches now-24h"

f="$WORKDIR/thirty"; : > "$f"; touch_days_ago 30 "$f"
assert_close_to_now_minus 30 "$f" "30 days ago: mtime matches now-30d"

# --- bad input fails loudly, leaves the file untouched, rather than a silent no-op ---
f="$WORKDIR/bad"; : > "$f"
before="$(mtime_epoch "$f")"
if touch_days_ago "not-a-number" "$f" 2>/dev/null; then
	_ko "bad input: touch_days_ago should fail, not succeed"
else
	_ok "bad input: touch_days_ago fails loudly"
fi
assert_eq "$(mtime_epoch "$f")" "$before" "bad input: file mtime left unchanged, not silently corrupted"

rm -rf "$WORKDIR"
finish
