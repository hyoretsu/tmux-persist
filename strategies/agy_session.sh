#!/usr/bin/env bash

# "agy (Antigravity) session strategy"
#
# Google's Antigravity CLI (`agy`) resumes the most recent conversation in the
# workspace with `agy --continue`; `--conversation=<id>` / `-c <id>` target a
# specific one. A bare launch starts an empty session, so restore continues the
# last one.
#
# Behavior:
#   - If the saved command already continues or names a conversation, pass it
#     through unchanged.
#   - Otherwise append `--continue`, preserving any other captured flags.

ORIGINAL_COMMAND="$1"
DIRECTORY="$2"

original_command_already_resumes() {
	[[ "$ORIGINAL_COMMAND" =~ (^|[[:space:]])(--continue|--conversation|-c)([[:space:]=]|$) ]]
}

main() {
	if original_command_already_resumes; then
		echo "$ORIGINAL_COMMAND"
	else
		echo "$ORIGINAL_COMMAND --continue"
	fi
}
main
