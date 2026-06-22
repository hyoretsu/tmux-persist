#!/usr/bin/env bash

# "cursor-agent session strategy"
#
# Cursor's CLI agent (`cursor-agent`) continues the previous conversation with
# `cursor-agent --continue`; `resume` / `--resume="<id>"` target a specific one.
# A bare launch starts an empty session, so restore continues the last one.
#
# Behavior:
#   - If the saved command already continues/resumes (flag or `resume`
#     subcommand), pass it through unchanged.
#   - Otherwise append `--continue`, preserving any other captured flags.

ORIGINAL_COMMAND="$1"
DIRECTORY="$2"

original_command_already_resumes() {
	[[ "$ORIGINAL_COMMAND" =~ (^|[[:space:]])(--continue|--resume|resume)([[:space:]=]|$) ]]
}

main() {
	if original_command_already_resumes; then
		echo "$ORIGINAL_COMMAND"
	else
		echo "$ORIGINAL_COMMAND --continue"
	fi
}
main
