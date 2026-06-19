#!/usr/bin/env bash

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

source "$CURRENT_DIR/scripts/variables.sh"
source "$CURRENT_DIR/scripts/helpers.sh"

set_save_bindings() {
	local key_bindings=$(get_tmux_option "$save_option" "$default_save_key")
	local key
	for key in $key_bindings; do
		tmux bind-key "$key" run-shell "$CURRENT_DIR/scripts/save.sh"
	done
}

set_restore_bindings() {
	local key_bindings=$(get_tmux_option "$restore_option" "$default_restore_key")
	local key
	for key in $key_bindings; do
		tmux bind-key "$key" run-shell "$CURRENT_DIR/scripts/restore.sh"
	done
}

set_default_strategies() {
	tmux set-option -gq "${restore_process_strategy_option}irb" "default_strategy"
	tmux set-option -gq "${restore_process_strategy_option}mosh-client" "default_strategy"
}

set_script_path_options() {
	tmux set-option -gq "$save_path_option" "$CURRENT_DIR/scripts/save.sh"
	tmux set-option -gq "$restore_path_option" "$CURRENT_DIR/scripts/restore.sh"
}

set_save_on_exit_hooks() {
	local enabled="$(get_tmux_option "$save_on_exit_option" "$default_save_on_exit")"
	[ "$enabled" = "on" ] || return
	local save_command="run-shell \"$CURRENT_DIR/scripts/save.sh quiet\""
	# Replace (not append) so re-sourcing the config does not stack duplicate
	# hooks. '2>/dev/null' keeps older tmux versions (without these hooks) quiet.
	local hook
	for hook in client-detached session-closed; do
		tmux set-hook -g "$hook" "$save_command" 2>/dev/null
	done
}

set_auto_restore_hook() {
	local enabled="$(get_tmux_option "$auto_restore_option" "$default_auto_restore")"
	[ "$enabled" = "on" ] || return
	# When a session is created, restore its saved contents (quietly: most new
	# sessions have no snapshot). '#{hook_session_name}' is the new session's
	# name. Replace, not append, to stay idempotent across config reloads.
	tmux set-hook -g session-created \
		"run-shell \"$CURRENT_DIR/scripts/restore.sh #{hook_session_name} quiet\"" 2>/dev/null
}

main() {
	set_save_bindings
	set_restore_bindings
	set_default_strategies
	set_script_path_options
	set_save_on_exit_hooks
	set_auto_restore_hook
}
main
