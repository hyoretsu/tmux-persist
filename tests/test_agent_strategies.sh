#!/usr/bin/env bash
# Agent CLI session restore: the claude/codex restore strategies rewrite a bare
# launch into a resume, preserve an explicit resume, and are wired as defaults.

source "$(dirname "$0")/helpers/test_helpers.sh"

CLAUDE="$PLUGIN_DIR/strategies/claude_session.sh"
CODEX="$PLUGIN_DIR/strategies/codex_session.sh"
COPILOT="$PLUGIN_DIR/strategies/copilot_session.sh"
CURSOR="$PLUGIN_DIR/strategies/cursor-agent_session.sh"
AGY="$PLUGIN_DIR/strategies/agy_session.sh"
GEMINI="$PLUGIN_DIR/strategies/gemini_session.sh"
OPENCODE="$PLUGIN_DIR/strategies/opencode_session.sh"

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

# --- copilot_session.sh ---
assert_strategy "$COPILOT" "bare copilot gets --continue" \
	"copilot" "copilot --continue"
assert_strategy "$COPILOT" "copilot --continue not duplicated" \
	"copilot --continue" "copilot --continue"
assert_strategy "$COPILOT" "copilot --resume <id> preserved" \
	"copilot --resume abc123" "copilot --resume abc123"

# --- cursor-agent_session.sh ---
assert_strategy "$CURSOR" "bare cursor-agent gets --continue" \
	"cursor-agent" "cursor-agent --continue"
assert_strategy "$CURSOR" "cursor-agent resume subcommand preserved" \
	"cursor-agent resume" "cursor-agent resume"
assert_strategy "$CURSOR" "cursor-agent --resume=<id> preserved" \
	"cursor-agent --resume=abc123" "cursor-agent --resume=abc123"

# --- agy_session.sh ---
assert_strategy "$AGY" "bare agy gets --continue" \
	"agy" "agy --continue"
assert_strategy "$AGY" "agy --conversation=<id> preserved" \
	"agy --conversation=abc123" "agy --conversation=abc123"
assert_strategy "$AGY" "agy -c <id> preserved" \
	"agy -c abc123" "agy -c abc123"

# --- gemini_session.sh ---
assert_strategy "$GEMINI" "bare gemini gets --resume" \
	"gemini" "gemini --resume"
assert_strategy "$GEMINI" "gemini --resume not duplicated" \
	"gemini --resume" "gemini --resume"
assert_strategy "$GEMINI" "gemini -r preserved" \
	"gemini -r" "gemini -r"

# --- opencode_session.sh ---
assert_strategy "$OPENCODE" "bare opencode gets --continue" \
	"opencode" "opencode --continue"
assert_strategy "$OPENCODE" "opencode -c not duplicated" \
	"opencode -c" "opencode -c"
assert_strategy "$OPENCODE" "opencode --session <id> preserved" \
	"opencode --session abc123" "opencode --session abc123"

# --- wiring (default proc list + default strategy registration) ---
source "$PLUGIN_DIR/scripts/variables.sh"
for agent in claude codex copilot cursor-agent agy gemini opencode; do
	assert_contains "$default_proc_list" "$agent" "$agent in default_proc_list"
done

setup
load_plugin
strategies="$(tmuxp show-options -g 2>/dev/null)"
teardown
for agent in claude codex copilot cursor-agent agy gemini opencode; do
	assert_contains "$strategies" "${restore_process_strategy_option}${agent} session" \
		"$agent registered as 'session' strategy"
done

# --- strategy files are executable ---
for f in "$CLAUDE" "$CODEX" "$COPILOT" "$CURSOR" "$AGY" "$GEMINI" "$OPENCODE"; do
	[ -x "$f" ] && _ok "$(basename "$f") executable" || _ko "$(basename "$f") executable"
done

finish
