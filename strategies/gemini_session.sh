#!/usr/bin/env bash

# "gemini session strategy"
#
# Google's Gemini CLI (`gemini`) loads the most recent session on launch with
# `gemini --resume` (short `-r`). A bare launch starts an empty session, so
# restore rewrites it to resume the last one.
#
# Behavior:
#   - If the saved command already resumes, pass it through unchanged.
#   - Otherwise append `--resume`, preserving any other captured flags.

ORIGINAL_COMMAND="$1"
DIRECTORY="$2"

original_command_already_resumes() {
	[[ "$ORIGINAL_COMMAND" =~ (^|[[:space:]])(--resume|-r)([[:space:]=]|$) ]]
}

main() {
	if original_command_already_resumes; then
		echo "$ORIGINAL_COMMAND"
	else
		echo "$ORIGINAL_COMMAND --resume"
	fi
}
main
