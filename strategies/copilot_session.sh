#!/usr/bin/env bash

# "copilot session strategy"
#
# GitHub Copilot CLI (`copilot`) resumes the most recent conversation with
# `copilot --continue`; `--resume [id]` targets a specific one. A bare launch
# starts an empty session, so restore rewrites it to continue the last one.
#
# Behavior:
#   - If the saved command already continues/resumes, pass it through unchanged.
#   - Otherwise append `--continue`, preserving any other captured flags.

ORIGINAL_COMMAND="$1"
DIRECTORY="$2"

original_command_already_resumes() {
	[[ "$ORIGINAL_COMMAND" =~ (^|[[:space:]])(--continue|--resume)([[:space:]=]|$) ]]
}

main() {
	if original_command_already_resumes; then
		echo "$ORIGINAL_COMMAND"
	else
		echo "$ORIGINAL_COMMAND --continue"
	fi
}
main
