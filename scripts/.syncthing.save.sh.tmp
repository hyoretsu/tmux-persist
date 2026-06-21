#!/usr/bin/env bash

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

source "$CURRENT_DIR/variables.sh"
source "$CURRENT_DIR/helpers.sh"
source "$CURRENT_DIR/spinner_helpers.sh"

# delimiters
d=$'\t'
delimiter=$'\t'

# Arguments (any order):
#   quiet         - produce no output (used by hooks)
#   all           - save every session (used by the auto-save-on-exit hooks,
#                   which fire without a "current session" to target)
#   <session>     - save this session instead of the current one
# Without "all" or a session argument the session the client is attached to is
# saved.
SCRIPT_OUTPUT=""
SAVE_SESSION=""
SAVE_ALL="false"
for arg in "$@"; do
	case "$arg" in
		quiet) SCRIPT_OUTPUT="quiet" ;;
		all) SAVE_ALL="true" ;;
		*) SAVE_SESSION="$arg" ;;
	esac
done
if [ "$SAVE_ALL" != "true" ] && [ -z "$SAVE_SESSION" ]; then
	SAVE_SESSION="$(tmux display-message -p "#{client_session}")"
fi

grouped_sessions_format() {
	local format
	format+="#{session_grouped}"
	format+="${delimiter}"
	format+="#{session_group}"
	format+="${delimiter}"
	format+="#{session_id}"
	format+="${delimiter}"
	format+="#{session_name}"
	echo "$format"
}

pane_format() {
	local format
	format+="pane"
	format+="${delimiter}"
	format+="#{session_name}"
	format+="${delimiter}"
	format+="#{window_index}"
	format+="${delimiter}"
	format+="#{window_active}"
	format+="${delimiter}"
	format+=":#{window_flags}"
	format+="${delimiter}"
	format+="#{pane_index}"
	format+="${delimiter}"
	format+="#{pane_title}"
	format+="${delimiter}"
	format+=":#{pane_current_path}"
	format+="${delimiter}"
	format+="#{pane_active}"
	format+="${delimiter}"
	format+="#{pane_current_command}"
	format+="${delimiter}"
	format+="#{pane_pid}"
	format+="${delimiter}"
	format+="#{history_size}"
	echo "$format"
}

window_format() {
	local format
	format+="window"
	format+="${delimiter}"
	format+="#{session_name}"
	format+="${delimiter}"
	format+="#{window_index}"
	format+="${delimiter}"
	format+=":#{window_name}"
	format+="${delimiter}"
	format+="#{window_active}"
	format+="${delimiter}"
	format+=":#{window_flags}"
	format+="${delimiter}"
	format+="#{window_layout}"
	echo "$format"
}

dump_panes_raw() {
	tmux list-panes -s -t "$1" -F "$(pane_format)"
}

dump_windows_raw(){
	tmux list-windows -t "$1" -F "$(window_format)"
}

toggle_window_zoom() {
	local target="$1"
	tmux resize-pane -Z -t "$target"
}

_save_command_strategy_file() {
	local save_command_strategy="$(get_tmux_option "$save_command_strategy_option" "$default_save_command_strategy")"
	local strategy_file="$CURRENT_DIR/../save_command_strategies/${save_command_strategy}.sh"
	local default_strategy_file="$CURRENT_DIR/../save_command_strategies/${default_save_command_strategy}.sh"
	if [ -e "$strategy_file" ]; then # strategy file exists?
		echo "$strategy_file"
	else
		echo "$default_strategy_file"
	fi
}

pane_full_command() {
	local pane_pid="$1"
	local strategy_file="$(_save_command_strategy_file)"
	# execute strategy script to get pane full command
	$strategy_file "$pane_pid"
}

number_nonempty_lines_on_screen() {
	local pane_id="$1"
	tmux capture-pane -pJ -t "$pane_id" |
		sed '/^$/d' |
		wc -l |
		sed 's/ //g'
}

# tests if there was any command output in the current pane
pane_has_any_content() {
	local pane_id="$1"
	local history_size="$(tmux display -p -t "$pane_id" -F "#{history_size}")"
	local cursor_y="$(tmux display -p -t "$pane_id" -F "#{cursor_y}")"
	# doing "cheap" tests first
	[ "$history_size" -gt 0 ] || # history has any content?
		[ "$cursor_y" -gt 0 ] || # cursor not in first line?
		[ "$(number_nonempty_lines_on_screen "$pane_id")" -gt 1 ]
}

# True when the trailing content of the pane is a shell prompt rather than a live
# full-screen program - the cursor is at or below the last non-blank row. That
# covers both an idle shell (cursor on its prompt) and a shell that just exited
# via Ctrl-d/EOF (cursor jumped past the prompt to the bottom). It is false only
# when the cursor sits ABOVE the last content, i.e. a full-screen app (vim, less)
# is drawing - exactly when the trailing lines must not be treated as a prompt.
# Capture the visible rows without -J so row indices line up with #{cursor_y}.
pane_prompt_at_bottom() {
	local pane_id="$1"
	local cursor_y="$(tmux display -p -t "$pane_id" -F "#{cursor_y}")"
	local last_row="$(tmux capture-pane -ep -t "$pane_id" |
		awk -v esc="$(printf '\033')" '
			function visible(s) {
				gsub(esc "\\[[0-9;?]*[ -/]*[@-~]", "", s)
				gsub(esc "\\][^\007]*\007", "", s)
				gsub(/[ \t]+$/, "", s)
				return s
			}
			{ if (visible($0) != "") last = NR }
			END { print last - 1 }')"
	[ "$cursor_y" -ge "$last_row" ] 2>/dev/null
}

capture_pane_contents() {
	local pane_id="$1"
	local start_line="-$2"
	local pane_contents_area="$3"
	if pane_has_any_content "$pane_id"; then
		if [ "$pane_contents_area" = "visible" ]; then
			start_line="0"
		fi
		# Drop trailing blank lines (incl. escape-only prompt redraws) so a
		# Ctrl-d exit doesn't leave a gap of empty lines in the snapshot. When the
		# pane's trailing content is a shell prompt (idle, or just exited via EOF),
		# drop that prompt too: the restored shell redraws its own, so keeping it
		# yields a duplicate that piles up across save/restore cycles.
		local filter="strip_trailing_blank_lines"
		pane_prompt_at_bottom "$pane_id" && filter="strip_trailing_prompt"
		tmux capture-pane -epJ -S "$start_line" -t "$pane_id" |
			"$filter" > "$(pane_contents_file "save" "$pane_id")"
	fi
}

get_active_window_index() {
	local session_name="$1"
	tmux list-windows -t "$session_name" -F "#{window_flags} #{window_index}" |
		awk '$1 ~ /\*/ { print $2; }'
}

get_alternate_window_index() {
	local session_name="$1"
	tmux list-windows -t "$session_name" -F "#{window_flags} #{window_index}" |
		awk '$1 ~ /-/ { print $2; }'
}

dump_grouped_sessions() {
	local current_session_group=""
	local original_session
	tmux list-sessions -F "$(grouped_sessions_format)" |
		grep "^1" |
		cut -c 3- |
		sort |
		while IFS=$d read session_group session_id session_name; do
			if [ "$session_group" != "$current_session_group" ]; then
				# this session is the original/first session in the group
				original_session="$session_name"
				current_session_group="$session_group"
			else
				# this session "points" to the original session
				active_window_index="$(get_active_window_index "$session_name")"
				alternate_window_index="$(get_alternate_window_index "$session_name")"
				echo "grouped_session${d}${session_name}${d}${original_session}${d}:${alternate_window_index}${d}:${active_window_index}"
			fi
		done
}

# Emits the single "grouped_session" line for the given session, if it is a
# grouped (secondary) session. Reads the pre-computed dump from the environment.
dump_grouped_session_line() {
	local session="$1"
	echo "$GROUPED_SESSIONS_DUMP" |
		awk -v s="$session" 'BEGIN { FS="\t" } $1 == "grouped_session" && $2 == s'
}

# translates pane pid to process command running inside a pane
dump_panes() {
	local full_command
	dump_panes_raw "$1" |
		while IFS=$d read line_type session_name window_number window_active window_flags pane_index pane_title dir pane_active pane_command pane_pid history_size; do
			# not saving panes from grouped sessions
			if is_session_grouped "$session_name"; then
				continue
			fi
			full_command="$(pane_full_command $pane_pid)"
			dir=$(echo $dir | sed 's/ /\\ /') # escape all spaces in directory path
			echo "${line_type}${d}${session_name}${d}${window_number}${d}${window_active}${d}${window_flags}${d}${pane_index}${d}${pane_title}${d}${dir}${d}${pane_active}${d}${pane_command}${d}:${full_command}"
		done
}

dump_windows() {
	dump_windows_raw "$1" |
		while IFS=$d read line_type session_name window_index window_name window_active window_flags window_layout; do
			# not saving windows from grouped sessions
			if is_session_grouped "$session_name"; then
				continue
			fi
			automatic_rename="$(tmux show-window-options -vt "${session_name}:${window_index}" automatic-rename)"
			# If the option was unset, use ":" as a placeholder.
			[ -z "${automatic_rename}" ] && automatic_rename=":"
			echo "${line_type}${d}${session_name}${d}${window_index}${d}${window_name}${d}${window_active}${d}${window_flags}${d}${window_layout}${d}${automatic_rename}"
			dump_window_options "$session_name" "$window_index"
		done
}

# Emits one "wopt" line per locally-set window option (e.g. monitor-activity),
# so per-window options survive restore. `show-options -w` (no -g) lists only the
# overrides set on the window, not inherited globals. The distinct "wopt" line
# type avoids the `^window` / `^pane` greps; older snapshots simply lack these
# lines. (tmux-resurrect#132)
dump_window_options() {
	local session_name="$1"
	local window_index="$2"
	tmux show-options -w -t "${session_name}:${window_index}" 2>/dev/null |
		while IFS= read -r opt; do
			[ -n "$opt" ] && echo "wopt${d}${session_name}${d}${window_index}${d}${opt}"
		done
}

dump_pane_contents() {
	local pane_contents_area="$(get_tmux_option "$pane_contents_area_option" "$default_pane_contents_area")"
	dump_panes_raw "$1" |
		while IFS=$d read line_type session_name window_number window_active window_flags pane_index pane_title dir pane_active pane_command pane_pid history_size; do
			capture_pane_contents "${session_name}:${window_number}.${pane_index}" "$history_size" "$pane_contents_area"
		done
}

# Saves one session as a single snapshot file, "<session>_<timestamp>.tgz",
# bundling its layout and (when enabled) its pane contents.
save_session() {
	local session="$1"
	local layout_file="$(snapshot_layout_file "save")"

	# Build the snapshot in the staging area: ./layout (+ ./pane_contents/).
	rm -rf "$(persist_dir)/save"
	mkdir -p "$(persist_dir)/save"

	if is_session_grouped "$session"; then
		# grouped sessions share the original session's layout, so we only
		# record the grouping itself - never panes, windows or pane contents.
		dump_grouped_session_line "$session" > "$layout_file"
	else
		{
			dump_panes   "$session"
			dump_windows "$session"
		} > "$layout_file"
		if [ "$CAPTURE_PANE_CONTENTS" = "on" ]; then
			mkdir -p "$(pane_contents_dir "save")"
			dump_pane_contents "$session"
		fi
	fi

	execute_hook "post-save-layout" "$layout_file"

	snapshot_create "$session"

	# remove the whole staging tree, not just its files
	rm -rf "$(persist_dir)/save"
}

save_all() {
	# Nothing to save (e.g. invoked with no attached client and no session arg).
	[ "$SAVE_ALL" = "true" ] || [ -n "$SAVE_SESSION" ] || return
	mkdir -p "$(persist_dir)"
	# Compute grouped-session info. It is needed so that panes/windows belonging
	# to a grouped session are skipped (they share the original session's
	# layout). Both are exported so save_session and its subshells can read them.
	export GROUPED_SESSIONS_DUMP="$(dump_grouped_sessions)"
	get_grouped_sessions "$GROUPED_SESSIONS_DUMP"
	export CAPTURE_PANE_CONTENTS="off"
	capture_pane_contents_option_on && export CAPTURE_PANE_CONTENTS="on"

	if [ "$SAVE_ALL" = "true" ]; then
		# Used by the auto-save-on-exit hooks: tmux gives no "current session"
		# on detach, so save every live session to be safe.
		tmux list-sessions -F "#{session_name}" 2>/dev/null |
			while IFS= read -r session; do
				save_session "$session"
			done
	else
		save_session "$SAVE_SESSION"
	fi

	# Drop snapshots that are now too old, across all sessions.
	prune_all_old_backups

	execute_hook "post-save-all"
}

show_output() {
	[ "$SCRIPT_OUTPUT" != "quiet" ]
}

main() {
	if supported_tmux_version_ok; then
		if show_output; then
			start_spinner "Saving..." "Tmux environment saved!"
		fi
		save_all
		if show_output; then
			stop_spinner
			display_message "Tmux environment saved!"
		fi
	fi
}
main
