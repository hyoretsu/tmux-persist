#!/usr/bin/env bash
# Common terminal file managers are restored by default (they just reopen a
# directory view). (tmux-resurrect#106)

source "$(dirname "$0")/helpers/test_helpers.sh"
setup

# Ask the real restore-list matcher whether a command would be restored.
on_list() { # command
	local out="$TEST_PERSIST_DIR/onlist.out"
	rm -f "$out"
	tmuxp run-shell "bash -c 'CURRENT_DIR=\"$PLUGIN_DIR/scripts\"; \
		source \"$PLUGIN_DIR/scripts/variables.sh\"; \
		source \"$PLUGIN_DIR/scripts/helpers.sh\"; \
		source \"$PLUGIN_DIR/scripts/process_restore_helpers.sh\"; \
		{ _process_on_the_restore_list \"\$1\" && echo YES || echo NO ; } > \"$out\"' _ '$1'"
	sleep 0.4
	cat "$out"
}

for fm in ranger nnn lf vifm mc; do
	assert_eq "$(on_list "$fm /home/user")" "YES" "$fm is restored by default"
done

# A non-listed program is still not restored by default.
assert_eq "$(on_list 'some_random_daemon --serve')" "NO" "unlisted program not restored by default"

teardown
finish
