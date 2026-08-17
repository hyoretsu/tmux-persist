#!/usr/bin/env bash
# Restored panes should invoke the configured shell as a *login* shell so login
# files are sourced. Previously only bash got the -l flag; zsh/fish/etc. were
# started as non-login shells. login_shell_opt now flags any configured shell.
# (tmux-resurrect#497)

source "$(dirname "$0")/helpers/test_helpers.sh"
setup

# Evaluate login_shell_opt inside the test tmux server (so the bare `tmux`
# calls in helpers.sh hit the test socket), writing the result to a file.
probe_login_opt() { # shell-path
	local out="$TEST_PERSIST_DIR/opt.out"
	rm -f "$out"
	tmuxp run-shell "bash -c 'CURRENT_DIR=\"$PLUGIN_DIR/scripts\"; \
		source \"$PLUGIN_DIR/scripts/variables.sh\"; \
		source \"$PLUGIN_DIR/scripts/helpers.sh\"; \
		printf \"[%s]\" \"\$(login_shell_opt \"$1\")\" > \"$out\"'"
	sleep 0.4
	cat "$out"
}

assert_eq "$(probe_login_opt /usr/bin/zsh)"  "[-l ]" "zsh is started as a login shell"
assert_eq "$(probe_login_opt /usr/bin/fish)" "[-l ]" "fish is started as a login shell"
assert_eq "$(probe_login_opt /bin/bash)"     "[-l ]" "bash still gets -l (no regression)"
assert_eq "$(probe_login_opt '')"            "[]"    "no configured shell -> no flag"

teardown
finish
