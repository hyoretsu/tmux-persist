#!/usr/bin/env bash
# Unnamed (numeric-named) sessions are saved by default, like any other
# session - nothing is ever silently dropped out of the box. Skipping them
# (to avoid littering the persist dir with tmux's own throwaway auto-numbered
# sessions) is opt-in via @persist-save-unnamed 'off'.
#
# is_session_unnamed() can't just pattern-match the name (see helpers.sh): a
# session a user explicitly named with `-s <number>` is a real, intentional
# name that happens to look numeric, not tmux's own auto-assigned counter -
# both produce an identical string. Detection instead compares the name
# against the session's own #{session_id} (tmux's actual auto-naming
# formula), which only false-positives for a name that coincidentally equals
# that specific session's hidden internal counter value.

source "$(dirname "$0")/helpers/test_helpers.sh"
setup

# A session created without -s gets a numeric tmux name (0, 1, 2, ...).
unnamed="$(tmuxp new-session -dP -F '#{session_name}')"
assert_eq "$(printf '%s' "$unnamed" | grep -cE '^[0-9]+$')" "1" \
	"new-session without -s is numeric-named ($unnamed)"

# --- default: nothing is skipped, not even a genuinely auto-named session ---
save all
assert_file "$TEST_PERSIST_DIR/${unnamed}_"*.tgz "unnamed session saved by default"
assert_file "$TEST_PERSIST_DIR/${unnamed}_last" "unnamed session has a last pointer by default"

teardown

# =====================================================================
# Opt out (@persist-save-unnamed off): genuinely auto-named sessions are now
# skipped. With no client attached anywhere on the server (the common state
# for a headless auto-save - display-message needs SOME client to show up
# in, `-t` or not), whether the warning actually displays is tmux-version/
# platform-dependent (confirmed: some tmux builds show it against a valid
# session target with zero clients attached, others require a real client
# and fail with "no current client" either way) - so the invariant this
# checks is NOT "it must fail here", it's the consistency between the two:
# the skip is marked "warned" if, and only if, the warning actually showed.
# A save is never marked warned for a warning nobody could have seen, so a
# later save (possibly with a real client attached by then) still gets a
# real chance to show it.
# =====================================================================
setup
tmuxp set -g @persist-save-unnamed off

unnamed="$(tmuxp new-session -dP -F '#{session_name}')"
assert_eq "$(tmuxp list-clients 2>/dev/null | wc -l | tr -d ' ')" "0" \
	"sanity: no client attached"

save all
assert_no_file "$TEST_PERSIST_DIR/${unnamed}_"*.tgz "unnamed session not saved when opted out"
assert_no_file "$TEST_PERSIST_DIR/${unnamed}_last" "no last pointer for unnamed session when opted out"
shown="$(tmuxp show-messages | grep -c "skipped saving unnamed session '$unnamed'")"
marked="$(tmuxp show-options -t "$unnamed" -qv @persist-unnamed-warned 2>/dev/null)"
if [ "$shown" -gt 0 ]; then
	assert_eq "$marked" "1" "marked warned since the warning did show, even with no client"
else
	assert_eq "$marked" "" "not marked warned since the warning did not show"
fi

# --- named session alongside it is still saved ---
make_session proj PROJ_MARK
save all
assert_file "$TEST_PERSIST_DIR/proj_"*.tgz "named session saved even when opted out"

teardown

# =====================================================================
# Same as above, but with a real attached client: the warning must actually
# show, and show only once per session across repeated saves.
# =====================================================================
setup
tmuxp set -g @persist-save-unnamed off

unnamed="$(tmuxp new-session -dP -F '#{session_name}')"
attach_control_client "$unnamed"
ctrl_pid="$CONTROL_CLIENT_PID"

save all
assert_contains "$(tmuxp show-messages)" "skipped saving unnamed session '$unnamed'" \
	"warning shown for the skipped unnamed session when a client is attached"
assert_eq "$(tmuxp show-options -t "$unnamed" -qv @persist-unnamed-warned 2>/dev/null)" "1" \
	"marked warned once the warning was actually shown"

# --- the warning fires only once per session, not on every save ---
warning_count_before="$(tmuxp show-messages | grep -c "skipped saving unnamed session '$unnamed'")"
save all
save all
warning_count_after="$(tmuxp show-messages | grep -c "skipped saving unnamed session '$unnamed'")"
assert_eq "$warning_count_after" "$warning_count_before" \
	"warning does not repeat on subsequent saves of the same session"

detach_all_control_clients
teardown

# =====================================================================
# A session explicitly named with -s, that happens to look numeric, is a
# real, deliberate name - not tmux's auto-naming counter. Even under
# opt-out mode, this must not be silently dropped. Regression test for the
# confirmed bug: before the #{session_id}-based fix, this session was
# indistinguishable from a genuinely unnamed one and got silently skipped.
# =====================================================================
setup
tmuxp set -g @persist-save-unnamed off

tmuxp new-session -d -s 42
tmuxp send-keys -t 42 "echo NAMED_42_MARK" Enter
sleep 0.3

save all
assert_file "$TEST_PERSIST_DIR/42_"*.tgz \
	"explicitly-named session '42' is saved despite looking numeric, even when opted out"
assert_file "$TEST_PERSIST_DIR/42_last" "'42' has a last pointer"

teardown
finish
