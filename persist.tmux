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
	tmux set-option -gq "${restore_process_strategy_option}claude" "session"
	tmux set-option -gq "${restore_process_strategy_option}codex" "session"
}

set_script_path_options() {
	tmux set-option -gq "$save_path_option" "$CURRENT_DIR/scripts/save.sh"
	tmux set-option -gq "$restore_path_option" "$CURRENT_DIR/scripts/restore.sh"
}

set_save_on_exit_hooks() {
	local hook
	if [ "$(get_tmux_option "$save_on_exit_option" "$default_save_on_exit")" = "on" ]; then
		# Save every session: on detach/close tmux exposes no "current session"
		# to target, so "all" is the only reliable choice here.
		local save_command="run-shell \"$CURRENT_DIR/scripts/save.sh quiet all\""
		# Replace (not append) so re-sourcing the config does not stack duplicate
		# hooks. '2>/dev/null' keeps older tmux versions (without these hooks) quiet.
		for hook in client-detached session-closed; do
			tmux set-hook -g "$hook" "$save_command" 2>/dev/null
		done
	else
		# Disabled: remove our hooks so toggling off actually takes effect.
		for hook in client-detached session-closed; do
			tmux set-hook -gu "$hook" 2>/dev/null
		done
	fi
}

set_auto_restore_hook() {
	if [ "$(get_tmux_option "$auto_restore_option" "$default_auto_restore")" = "on" ]; then
		# When a session is created, restore its saved contents (quietly: most new
		# sessions have no snapshot). '#{hook_session_name}' is the new session's
		# name. Replace, not append, to stay idempotent across config reloads.
		tmux set-hook -g session-created \
			"run-shell \"$CURRENT_DIR/scripts/restore.sh #{hook_session_name} quiet\"" 2>/dev/null
	else
		tmux set-hook -gu session-created 2>/dev/null
	fi
}

restore_existing_sessions_once() {
	if [ "$(get_tmux_option "$auto_restore_option" "$default_auto_restore")" = "on" ]; then
		# The session that starts the server is created before this plugin (loaded
		# via an async run-shell) can install the session-created hook, so it never
		# gets auto-restored. Restore already-existing sessions once per server
		# start. A marker option prevents re-running on every config reload, which
		# would clobber live sessions.
		if [ "$(get_tmux_option "$initialized_option" "")" != "1" ]; then
			tmux set-option -g "$initialized_option" 1
			tmux list-sessions -F "#{session_name}" 2>/dev/null |
				while IFS= read -r session; do
					"$CURRENT_DIR/scripts/restore.sh" "$session" quiet
				done
		fi
	fi
}

# If the user still has any old @resurrect-* options set, they keep working
# (see get_tmux_option), but advise migrating - once per server.
warn_legacy_options() {
	[ "$(tmux show-option -gqv @persist-legacy-warned)" = "1" ] && return
	if tmux show-options -g 2>/dev/null | grep -q '^@resurrect-'; then
		tmux set-option -g @persist-legacy-warned 1
		tmux display-message "tmux-persist: '@resurrect-*' options are deprecated - rename them to '@persist-*'."
	fi
}

main() {
	warn_legacy_options
	set_save_bindings
	set_restore_bindings
	set_default_strategies
	set_script_path_options
	set_save_on_exit_hooks
	set_auto_restore_hook
	migrate_legacy_snapshots
	prune_all_old_backups
	restore_existing_sessions_once
	return 0
}
main
