#!/usr/bin/env bash

# "opencode session strategy"
#
# `opencode` continues the most recent session with `opencode --continue`
# (short `-c`); `--session <id>` / `-s <id>` target a specific one. A bare
# launch starts an empty session, so restore continues the last one.
#
# Behavior:
#   - If the saved command already continues or names a session, pass it
#     through unchanged.
#   - Otherwise append `--continue`, preserving any other captured flags.

ORIGINAL_COMMAND="$1"
DIRECTORY="$2"

original_command_already_resumes() {
	[[ "$ORIGINAL_COMMAND" =~ (^|[[:space:]])(--continue|-c|--session|-s)([[:space:]=]|$) ]]
}

main() {
	if original_command_already_resumes; then
		echo "$ORIGINAL_COMMAND"
	else
		echo "$ORIGINAL_COMMAND --continue"
	fi
}
main
