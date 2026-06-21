#!/usr/bin/env bash
# `vi` and `view` are vim, but users only set @persist-strategy-vim and only
# vim_session.sh exists. Strategy lookup must alias vi/view to vim so they are
# restored with the session strategy (e.g. `-S`) like vim. (tmux-resurrect#323)

source "$(dirname "$0")/helpers/test_helpers.sh"
setup

tmuxp set -g @persist-strategy-vim "session"

# Run a process_restore_helpers function inside the test server, passing the
# pane command as a positional arg (avoids fragile nested re-quoting).
probe() { # func cmd
	local out="$TEST_PERSIST_DIR/probe.out"
	rm -f "$out"
	tmuxp run-shell "bash -c 'CURRENT_DIR=\"$PLUGIN_DIR/scripts\"; \
		source \"$PLUGIN_DIR/scripts/variables.sh\"; \
		source \"$PLUGIN_DIR/scripts/helpers.sh\"; \
		source \"$PLUGIN_DIR/scripts/process_restore_helpers.sh\"; \
		\"\$1\" \"\$2\" > \"$out\"' _ '$1' '$2'"
	sleep 0.4
	cat "$out"
}

assert_eq "$(probe _get_command_strategy 'vi file.txt')"   "session" "vi resolves vim's strategy"
assert_eq "$(probe _get_command_strategy 'view file.txt')" "session" "view resolves vim's strategy"
assert_eq "$(probe _get_command_strategy 'vim file.txt')"  "session" "vim still resolves its strategy"
assert_eq "$(probe _get_command_strategy 'nvim file.txt')" ""        "nvim is not aliased to vim"

assert_contains "$(probe _get_strategy_file 'vi file.txt')" "/strategies/vim_session.sh" \
	"vi uses the vim_session strategy file"

teardown
finish
