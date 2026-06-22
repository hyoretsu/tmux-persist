#!/usr/bin/env bash
# Agent CLI session restore: the claude/codex restore strategies rewrite a bare
# launch into a resume, preserve an explicit resume, and are wired as defaults.

source "$(dirname "$0")/helpers/test_helpers.sh"

CLAUDE="$PLUGIN_DIR/strategies/claude_session.sh"
CODEX="$PLUGIN_DIR/strategies/codex_session.sh"

assert_strategy() { # script desc input expected
	assert_eq "$("$1" "$3" "/some/dir")" "$4" "$2"
}

# --- claude_session.sh ---
assert_strategy "$CLAUDE" "bare claude gets --continue" \
	"claude" "claude --continue"
assert_strategy "$CLAUDE" "claude flags preserved, --continue appended" \
	"claude --model opus" "claude --model opus --continue"
assert_strategy "$CLAUDE" "claude --continue not duplicated" \
	"claude --continue" "claude --continue"
assert_strategy "$CLAUDE" "claude --resume <id> preserved" \
	"claude --resume abc123" "claude --resume abc123"
assert_strategy "$CLAUDE" "claude short -c preserved" \
	"claude -c" "claude -c"
assert_strategy "$CLAUDE" "claude short -r <id> preserved" \
	"claude -r abc123" "claude -r abc123"

# --- codex_session.sh ---
assert_strategy "$CODEX" "bare codex resumes last" \
	"codex" "codex resume --last"
assert_strategy "$CODEX" "codex with prompt resumes last" \
	"codex fix the bug" "codex resume --last"
assert_strategy "$CODEX" "codex --model flag still resumes last" \
	"codex --model gpt-5" "codex resume --last"
assert_strategy "$CODEX" "codex resume returned as-is" \
	"codex resume" "codex resume"
assert_strategy "$CODEX" "codex resume --last returned as-is" \
	"codex resume --last" "codex resume --last"
assert_strategy "$CODEX" "codex resume <id> preserved" \
	"codex resume abc123" "codex resume abc123"
assert_strategy "$CODEX" "codex fork <id> preserved" \
	"codex fork abc123" "codex fork abc123"

# --- wiring (default proc list + default strategy registration) ---
source "$PLUGIN_DIR/scripts/variables.sh"
assert_contains "$default_proc_list" "claude" "claude in default_proc_list"
assert_contains "$default_proc_list" "codex"  "codex in default_proc_list"

setup
load_plugin
strategies="$(tmuxp show-options -g 2>/dev/null)"
teardown
assert_contains "$strategies" "${restore_process_strategy_option}claude session" \
	"claude registered as 'session' strategy"
assert_contains "$strategies" "${restore_process_strategy_option}codex session" \
	"codex registered as 'session' strategy"

# --- strategy files are executable ---
[ -x "$CLAUDE" ] && _ok "claude_session.sh executable" || _ko "claude_session.sh executable"
[ -x "$CODEX" ]  && _ok "codex_session.sh executable"  || _ko "codex_session.sh executable"

finish
