#!/usr/bin/env bash

# "codex session strategy"
#
# OpenAI's `codex` CLI resumes a prior conversation with the `resume`
# subcommand; `codex resume --last` reopens the most recent one. As with
# Claude Code, re-launching the bare process starts a brand new conversation,
# so restore rewrites the captured command to resume the last session.
#
# Behavior:
#   - If the saved command is already a `resume`/`fork` invocation, pass it
#     through unchanged (it targets a specific session the user picked).
#   - Otherwise restore the most recent session with `codex resume --last`.

ORIGINAL_COMMAND="$1"
DIRECTORY="$2"

original_command_already_resumes() {
	[[ "$ORIGINAL_COMMAND" =~ (^|[[:space:]])(resume|fork)([[:space:]]|$) ]]
}

main() {
	if original_command_already_resumes; then
		echo "$ORIGINAL_COMMAND"
	else
		echo "codex resume --last"
	fi
}
main
