#!/usr/bin/env bash

# "claude session strategy"
#
# Claude Code's `claude` CLI cannot be resumed by re-launching the bare process:
# every conversation lives behind a session UUID. The CLI's own
# `claude --continue` reopens the most recent conversation for the pane's
# working directory, which is exactly what restore wants and needs no sidecar
# files, hooks, or knowledge of Claude's on-disk layout.
#
# Behavior:
#   - If the saved command already resumes/continues (long or short flag),
#     pass it through unchanged so the explicit choice wins.
#   - Otherwise append `--continue`, preserving any other captured flags.

ORIGINAL_COMMAND="$1"
DIRECTORY="$2"

original_command_already_resumes() {
	# Whole-token match so a `--continue` inside a prompt arg never trips it and
	# `-c` / `-r` short forms (claude's continue/resume) are caught too.
	[[ "$ORIGINAL_COMMAND" =~ (^|[[:space:]])(--continue|--resume|-c|-r)([[:space:]=]|$) ]]
}

main() {
	if original_command_already_resumes; then
		echo "$ORIGINAL_COMMAND"
	else
		echo "$ORIGINAL_COMMAND --continue"
	fi
}
main
