#!/usr/bin/env bash

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

source "$CURRENT_DIR/variables.sh"
source "$CURRENT_DIR/helpers.sh"
source "$CURRENT_DIR/process_restore_helpers.sh"
source "$CURRENT_DIR/spinner_helpers.sh"

# delimiter
d=$'\t'

# Global variable.
# Used during the restore: if a pane already exists from before, it is
# saved in the array in this variable. Later, process running in existing pane
# is also not restored. That makes the restoration process more idempotent.
EXISTING_PANES_VAR=""

RESTORING_FROM_SCRATCH="false"

# Whether detect_if_restoring_from_scratch() has already made its determination
# for the CURRENT session. Guards against re-detecting on a retry: that check's
# "exactly 1 live pane -> treat as fresh, overwrite it" heuristic is only valid
# on a session's first restore attempt. On a retry (restore_all_sessions()'s
# race-guard - see restore_structure_properties()), a session that's been
# reduced to 1 pane got there via a PARTIAL prior restore attempt, not a fresh
# empty session - re-running the detection would wrongly flag it as "from
# scratch" and overwrite that surviving pane's content. Reset to "false"
# once per session (not per attempt) by restore_all_sessions().
RESTORE_FROM_SCRATCH_CHECKED="false"

RESTORE_PANE_CONTENTS="false"

# Path to the extracted layout file of the snapshot being restored. Set once the
# snapshot is unpacked in restore_all_panes.
RESTORE_LAYOUT_FILE=""

# Arguments (any order):
#   quiet      - produce no output and no "file not found" message (used by the
#                auto-restore hook, which fires for every new session)
#   all        - restore every saved session, not just one (used e.g. by a
#                scheduled/boot-time restore with no "current session" to
#                target - see restore_all_sessions)
#   <session>  - restore this session instead of the current one
#   _deferred_focus_restore - internal, not user-facing: restores which
#              pane/window/session had focus for every saved session, without
#              re-restoring structure. Installed as a one-shot client-attached
#              hook by restore_all_sessions() when no client is attached at
#              bulk-restore time - see restore_focus_for_all_saved_sessions.
# Each session is saved separately (files named "<session>_*"), so restore only
# ever touches this one session. Without "all" or a session argument the
# session the client is attached to is restored.
RESTORE_SESSION=""
RESTORE_QUIET="false"
RESTORE_ALL="false"
RESTORE_DEFERRED_FOCUS="false"
for arg in "$@"; do
	case "$arg" in
		quiet) RESTORE_QUIET="true" ;;
		all) RESTORE_ALL="true" ;;
		_deferred_focus_restore) RESTORE_DEFERRED_FOCUS="true" ;;
		*) RESTORE_SESSION="$arg" ;;
	esac
done
if [ "$RESTORE_ALL" != "true" ] && [ "$RESTORE_DEFERRED_FOCUS" != "true" ] && [ -z "$RESTORE_SESSION" ]; then
	RESTORE_SESSION="$(tmux display-message -p "#{client_session}")"
fi

is_line_type() {
	local line_type="$1"
	local line="$2"
	echo "$line" |
		\grep -q "^$line_type"
}

check_saved_session_exists() {
	if ! snapshot_valid "$RESTORE_SESSION"; then
		# Missing, dangling, or 0-byte (corrupt/interrupted) snapshot: skip the
		# restore rather than feed tmux an empty file. In quiet mode (auto-restore
		# on session creation) staying silent is expected: most new sessions have
		# no saved snapshot.
		[ "$RESTORE_QUIET" = "true" ] || display_message "Tmux persist file not found or empty!"
		return 1
	fi
}

# Every session with a saved snapshot, decoded back to its real (unsanitized)
# name. "<session>_last" filenames are already sanitized (see
# _sanitize_session_for_path in helpers.sh), so this is the read-side
# counterpart of how save.sh names them.
all_saved_session_names() {
	shopt -s nullglob
	local link session
	for link in "$(persist_dir)/"*_last; do
		session="$(basename "$link")"
		session="${session%_last}"
		_unsanitize_session_from_path "$session"
	done
}

pane_exists() {
	local session_name="$1"
	local window_number="$2"
	local pane_index="$3"
	tmux list-panes -t "${session_name}:${window_number}" -F "#{pane_index}" 2>/dev/null |
		\grep -q "^$pane_index$"
}

register_existing_pane() {
	local session_name="$1"
	local window_number="$2"
	local pane_index="$3"
	local pane_custom_id="${session_name}:${window_number}:${pane_index}"
	local delimiter=$'\t'
	EXISTING_PANES_VAR="${EXISTING_PANES_VAR}${delimiter}${pane_custom_id}"
}

is_pane_registered_as_existing() {
	local session_name="$1"
	local window_number="$2"
	local pane_index="$3"
	local pane_custom_id="${session_name}:${window_number}:${pane_index}"
	[[ "$EXISTING_PANES_VAR" =~ "$pane_custom_id" ]]
}

restore_from_scratch_true() {
	RESTORING_FROM_SCRATCH="true"
}

is_restoring_from_scratch() {
	[ "$RESTORING_FROM_SCRATCH" == "true" ]
}

restore_pane_contents_true() {
	RESTORE_PANE_CONTENTS="true"
}

is_restoring_pane_contents() {
	[ "$RESTORE_PANE_CONTENTS" == "true" ]
}

window_exists() {
	local session_name="$1"
	local window_number="$2"
	tmux list-windows -t "$session_name" -F "#{window_index}" 2>/dev/null |
		\grep -q "^$window_number$"
}

session_exists() {
	local session_name="$1"
	tmux has-session -t "$session_name" 2>/dev/null
}

first_window_num() {
	tmux show -gv base-index
}

tmux_socket() {
	echo $TMUX | cut -d',' -f1
}

# Tmux option stored in a global variable so that we don't have to "ask"
# tmux server each time.
cache_tmux_default_command() {
	local default_shell="$(get_tmux_option "default-shell" "")"
	local opt=""
	if [ "$(basename "$default_shell")" == "bash" ]; then
		opt="-l "
	fi
	export TMUX_DEFAULT_COMMAND="$(get_tmux_option "default-command" "$opt$default_shell")"
}

tmux_default_command() {
	echo "$TMUX_DEFAULT_COMMAND"
}

pane_creation_command() {
	# Fall back to a real shell if tmux has no default command/shell configured.
	# Otherwise the pane would run "cat <file>; exec" with nothing after exec,
	# exit immediately and the pane (and possibly the session) would close.
	local shell_command="$(tmux_default_command)"
	[ -n "$shell_command" ] || shell_command="${SHELL:-/bin/sh}"
	echo "cat '$(pane_contents_file "restore" "${1}:${2}.${3}")'; exec $shell_command"
}

new_window() {
	local session_name="$1"
	local window_number="$2"
	local dir="$3"
	local pane_index="$4"
	local pane_id="${session_name}:${window_number}.${pane_index}"
	dir="${dir/#\~/$HOME}"
	if is_restoring_pane_contents && pane_contents_file_exists "$pane_id"; then
		local pane_creation_command="$(pane_creation_command "$session_name" "$window_number" "$pane_index")"
		tmux new-window -d -t "${session_name}:${window_number}" -c "$dir" "$pane_creation_command"
	else
		tmux new-window -d -t "${session_name}:${window_number}" -c "$dir"
	fi
}

new_session() {
	local session_name="$1"
	local window_number="$2"
	local dir="$3"
	local pane_index="$4"
	local pane_id="${session_name}:${window_number}.${pane_index}"
	if is_restoring_pane_contents && pane_contents_file_exists "$pane_id"; then
		local pane_creation_command="$(pane_creation_command "$session_name" "$window_number" "$pane_index")"
		TMUX="" tmux -S "$(tmux_socket)" new-session -d -s "$session_name" -c "$dir" "$pane_creation_command"
	else
		TMUX="" tmux -S "$(tmux_socket)" new-session -d -s "$session_name" -c "$dir"
	fi
	# change first window number if necessary
	local created_window_num="$(first_window_num)"
	if [ $created_window_num -ne $window_number ]; then
		tmux move-window -s "${session_name}:${created_window_num}" -t "${session_name}:${window_number}"
	fi
}

new_pane() {
	local session_name="$1"
	local window_number="$2"
	local dir="$3"
	local pane_index="$4"
	local pane_id="${session_name}:${window_number}.${pane_index}"
	if is_restoring_pane_contents && pane_contents_file_exists "$pane_id"; then
		local pane_creation_command="$(pane_creation_command "$session_name" "$window_number" "$pane_index")"
		tmux split-window -t "${session_name}:${window_number}" -c "$dir" "$pane_creation_command"
	else
		tmux split-window -t "${session_name}:${window_number}" -c "$dir"
	fi
	# minimize window so more panes can fit
	tmux resize-pane -t "${session_name}:${window_number}" -U "999"
}

restore_pane() {
	local pane="$1"
	while IFS=$d read line_type session_name window_number window_active window_flags pane_index pane_title dir pane_active pane_command pane_full_command; do
		dir="$(remove_first_char "$dir")"
		pane_full_command="$(remove_first_char "$pane_full_command")"
		if pane_exists "$session_name" "$window_number" "$pane_index"; then
			if is_restoring_from_scratch; then
				# overwrite the pane
				# happens only for the first pane if it's the only registered pane for the whole tmux server
				local pane_id="$(tmux display-message -p -F "#{pane_id}" -t "$session_name:$window_number")"
				new_pane "$session_name" "$window_number" "$dir" "$pane_index"
				tmux kill-pane -t "$pane_id"
				# Self-disabling, not just "happens only for the first pane in a
				# single pass" as the comment above describes: restore_all_sessions()
				# can call restore_all_panes() again on retry (see
				# RESTORE_FROM_SCRATCH_CHECKED), at which point every pane this
				# function already created on a prior attempt now "exists" too -
				# without resetting this here, every one of them would hit this
				# same overwrite branch again on the next attempt instead of the
				# safe register_existing_pane path below, repeatedly splitting and
				# killing panes that were already correctly restored.
				RESTORING_FROM_SCRATCH="false"
			else
				# Pane exists, no need to create it!
				# Pane existence is registered. Later, its process also won't be restored.
				register_existing_pane "$session_name" "$window_number" "$pane_index"
			fi
		elif window_exists "$session_name" "$window_number"; then
			new_pane "$session_name" "$window_number" "$dir" "$pane_index"
		elif session_exists "$session_name"; then
			new_window "$session_name" "$window_number" "$dir" "$pane_index"
		else
			new_session "$session_name" "$window_number" "$dir" "$pane_index"
		fi
		# set pane title
		tmux select-pane -t "$session_name:$window_number.$pane_index" -T "$pane_title"
	done < <(echo "$pane")
}

restore_grouped_session() {
	local grouped_session="$1"
	echo "$grouped_session" |
	while IFS=$d read line_type grouped_session original_session alternate_window active_window; do
		TMUX="" tmux -S "$(tmux_socket)" new-session -d -s "$grouped_session" -t "$original_session"
	done
}

restore_active_and_alternate_windows_for_grouped_sessions() {
	local grouped_session="$1"
	echo "$grouped_session" |
	while IFS=$d read line_type grouped_session original_session alternate_window_index active_window_index; do
		alternate_window_index="$(remove_first_char "$alternate_window_index")"
		active_window_index="$(remove_first_char "$active_window_index")"
		if [ -n "$alternate_window_index" ]; then
			tmux switch-client -t "${grouped_session}:${alternate_window_index}"
		fi
		if [ -n "$active_window_index" ]; then
			tmux switch-client -t "${grouped_session}:${active_window_index}"
		fi
	done
}

never_ever_overwrite() {
	local overwrite_option_value="$(get_tmux_option "$overwrite_option" "")"
	[ -n "$overwrite_option_value" ]
}

detect_if_restoring_from_scratch() {
	if never_ever_overwrite; then
		return
	fi
	# Only ever make this determination once per session - see
	# RESTORE_FROM_SCRATCH_CHECKED's declaration for why re-running it on a
	# retry would be wrong.
	[ "$RESTORE_FROM_SCRATCH_CHECKED" = "true" ] && return
	RESTORE_FROM_SCRATCH_CHECKED="true"
	# "From scratch" means the target session is freshly created (a single
	# pane). In that case its lone pane is overwritten by the restore.
	local total_number_of_panes="$(tmux list-panes -t "$RESTORE_SESSION" 2>/dev/null | wc -l | sed 's/ //g')"
	if [ "$total_number_of_panes" -eq 1 ]; then
		restore_from_scratch_true
	fi
}

# Restore pane contents whenever the extracted snapshot actually carries any -
# independent of the current capture option, so old snapshots still restore.
detect_if_restoring_pane_contents() {
	if [ -n "$(find "$(persist_dir)/restore/pane_contents" -type f -print 2>/dev/null | head -1)" ]; then
		cache_tmux_default_command
		restore_pane_contents_true
	fi
}

# functions called from main (ordered)

restore_all_panes() {
	detect_if_restoring_from_scratch   # sets a global variable
	# Unpack the snapshot (layout + pane contents) into the restore staging area.
	snapshot_extract "$RESTORE_SESSION"
	RESTORE_LAYOUT_FILE="$(snapshot_layout_file "restore")"
	detect_if_restoring_pane_contents  # sets a global variable
	while read line; do
		if is_line_type "pane" "$line"; then
			restore_pane "$line"
		fi
	done < "$RESTORE_LAYOUT_FILE"
}

restore_window_properties() {
	local window_name
	\grep '^window' "$RESTORE_LAYOUT_FILE" |
		while IFS=$d read line_type session_name window_number window_name window_active window_flags window_layout automatic_rename; do
			tmux select-layout -t "${session_name}:${window_number}" "$window_layout"

			# Below steps are properly handling window names and automatic-rename
			# option. `rename-window` is an extra command in some scenarios, but we
			# opted for always doing it to keep the code simple.
			window_name="$(remove_first_char "$window_name")"
			tmux rename-window -t "${session_name}:${window_number}" "$window_name"
			if [ "${automatic_rename}" = ":" ]; then
				tmux set-option -u -t "${session_name}:${window_number}" automatic-rename
			else
				tmux set-option -t "${session_name}:${window_number}" automatic-rename "$automatic_rename"
			fi
		done
}

restore_all_pane_processes() {
	if restore_pane_processes_enabled; then
		local pane_full_command
		awk 'BEGIN { FS="\t"; OFS="\t" } /^pane/ && $11 !~ "^:$" { print $2, $3, $6, $8, $11; }' "$RESTORE_LAYOUT_FILE" |
			while IFS=$d read -r session_name window_number pane_index dir pane_full_command; do
				dir="$(remove_first_char "$dir")"
				pane_full_command="$(remove_first_char "$pane_full_command")"
				restore_pane_process "$pane_full_command" "$session_name" "$window_number" "$pane_index" "$dir"
			done
	fi
}

restore_active_pane_for_each_window() {
	awk 'BEGIN { FS="\t"; OFS="\t" } /^pane/ && $9 == 1 { print $2, $3, $6; }' "$RESTORE_LAYOUT_FILE" |
		while IFS=$d read session_name window_number active_pane; do
			tmux switch-client -t "${session_name}:${window_number}"
			tmux select-pane -t "$active_pane"
		done
}

restore_zoomed_windows() {
	awk 'BEGIN { FS="\t"; OFS="\t" } /^pane/ && $5 ~ /Z/ && $9 == 1 { print $2, $3; }' "$RESTORE_LAYOUT_FILE" |
		while IFS=$d read session_name window_number; do
			tmux resize-pane -t "${session_name}:${window_number}" -Z
		done
}

# Creates each grouped session (tmux new-session -t, socket-targeted - no
# attached client needed). Restoring which window is active/alternate in it
# is a separate step; see restore_active_and_alternate_windows_for_all_grouped_sessions.
restore_grouped_sessions() {
	while read line; do
		if is_line_type "grouped_session" "$line"; then
			restore_grouped_session "$line"
		fi
	done < "$RESTORE_LAYOUT_FILE"
}

restore_active_and_alternate_windows_for_all_grouped_sessions() {
	while read line; do
		if is_line_type "grouped_session" "$line"; then
			restore_active_and_alternate_windows_for_grouped_sessions "$line"
		fi
	done < "$RESTORE_LAYOUT_FILE"
}

restore_active_and_alternate_windows() {
	awk 'BEGIN { FS="\t"; OFS="\t" } /^window/ && $6 ~ /[*-]/ { print $2, $5, $3; }' "$RESTORE_LAYOUT_FILE" |
		sort -u |
		while IFS=$d read session_name active_window window_number; do
			tmux switch-client -t "${session_name}:${window_number}"
		done
}

# Remove the restore staging tree (layout + any pane contents) once everything
# has been recreated. Doing it after 'restore_all_panes' also seems to fix fish
# shell users' restore problems.
cleanup_restored_pane_contents() {
	rm -rf "$(persist_dir)/restore"
}

show_output() {
	[ "$RESTORE_QUIET" != "true" ]
}

# Everything restore_structure() does AFTER pane/window creation: setting
# properties on windows that now exist, restoring processes, zoom state and
# grouped sessions. Unlike restore_all_panes() (idempotent - only creates
# what's missing), these are NOT safe to blindly re-run: restore_zoomed_windows
# uses `resize-pane -Z`, a toggle, so calling it twice on an already-correctly
# zoomed window un-zooms it; restore_grouped_sessions creates each grouped
# session unconditionally and errors "duplicate session" if it already exists.
# Kept separate from restore_all_panes so restore_all_sessions() can retry
# only the idempotent, race-prone creation step and run this exactly once
# regardless of how many creation attempts it took.
restore_structure_properties() {
	restore_window_properties >/dev/null 2>&1
	execute_hook "pre-restore-pane-processes"
	restore_all_pane_processes
	restore_zoomed_windows
	restore_grouped_sessions
}

# Session/window/pane structure, properties and processes. Safe to run with
# no attached client - nothing in here calls switch-client. Shared between
# restore_one_session and restore_all_sessions.
restore_structure() {
	restore_all_panes
	restore_structure_properties
}

restore_one_session() {
	if check_saved_session_exists; then
		show_output && start_spinner "Restoring..." "Tmux restore complete!"
		execute_hook "pre-restore-all"
		restore_structure
		# below functions restore exact cursor positions - need a real
		# attached client (switch-client)
		restore_active_pane_for_each_window
		restore_active_and_alternate_windows_for_all_grouped_sessions
		restore_active_and_alternate_windows
		cleanup_restored_pane_contents
		execute_hook "post-restore-all"
		if show_output; then
			stop_spinner
			display_message "Tmux restore complete!"
		fi
	fi
}

# Pane count recorded in a session's own saved snapshot layout, read straight
# from its "_last" file (not the restore staging area) - format-detected the
# same way snapshot_extract() does (tgz vs a plain layout file), since a
# separate-format snapshot ("@persist-snapshot-format separate") is a plain
# text file, not an archive: `tar xzOf` on it fails and would otherwise
# silently read as 0 panes for every such session, deflating the whole
# fleet's retry budget without any error. Used both for the upfront
# fleet-wide pane budget and, per session, as part of that session's
# expected count. An unreadable/missing snapshot yields 0 rather than
# aborting.
_saved_session_pane_count() {
	local session="$1" last target
	last="$(last_session_file "$session")"
	snapshot_valid "$session" || { echo 0; return; }
	target="$(readlink "$last")"
	case "$target" in
		*.tgz) tar xzOf "$last" ./layout 2>/dev/null | \grep -c $'^pane\t' ;;
		*) \grep -c $'^pane\t' "$last" 2>/dev/null ;;
	esac
}

# Restores every saved session in one pass (see all_saved_session_names).
# Deliberately does not restore which pane/window has focus (the three
# calls restore_one_session makes after restore_structure): "the" active
# pane/window doesn't have a coherent meaning across many sessions restored
# in one bulk pass, and those calls need a real attached client, which
# typically doesn't exist yet at the trigger points this mode is for (tmux
# startup, a scheduled job, tmux-continuum's boot-restore).
#
# A `tmux kill-server` used to recreate a bulk-restore source session returns
# before the server finishes reaping child panes (measured ~33ms/pane), so a
# session can start restoring while its old panes are still mid-teardown on
# the same socket, and silently lose or partially restore it. To guard against
# that, each session's restore is verified (live pane count vs. the count
# recorded in its own snapshot) and retried with exponential backoff on
# mismatch, up to a give-up budget that scales with the whole fleet's total
# saved pane count - a bigger bulk restore is expected to see more server
# contention, so it gets more time to settle. Each session's retry sequence is
# independent: there is no global give-up flag, so one persistently-broken
# session never shortens or suppresses retries for any other session in the
# same run.
restore_all_sessions() {
	local session
	local -a saved_sessions=()
	local total_expected_panes=0 pane_count

	while IFS= read -r session; do
		[ -n "$session" ] || continue
		saved_sessions+=("$session")
		pane_count="$(_saved_session_pane_count "$session")"
		total_expected_panes=$((total_expected_panes + pane_count))
	done < <(all_saved_session_names)

	# Give-up budget (ms) for one session's retry sequence: twice the teardown
	# time the whole fleet's worth of panes could plausibly still be taking
	# (~33ms/pane, doubled for headroom).
	local retry_budget_ms=$((total_expected_panes * 33 * 2))

	local any_saved="false" any_failed="false"
	local -a failed_sessions=()

	for session in "${saved_sessions[@]}"; do
		RESTORE_SESSION="$session"
		if check_saved_session_exists; then
			any_saved="true"
			execute_hook "pre-restore-all"
			# Reset once per session (not per retry attempt below) - see
			# RESTORE_FROM_SCRATCH_CHECKED's declaration.
			RESTORING_FROM_SCRATCH="false"
			RESTORE_FROM_SCRATCH_CHECKED="false"
			# Retry only the idempotent creation step (restore_all_panes) - the
			# rest of restore_structure() (window properties, zoom, grouped
			# sessions) is not safe to re-run and happens exactly once below,
			# after this converges or the budget is exhausted.
			restore_all_panes

			local expected_panes live_panes matched="false"
			expected_panes="$(\grep -c $'^pane\t' "$RESTORE_LAYOUT_FILE" 2>/dev/null)"
			live_panes="$(tmux list-panes -s -t "$session" 2>/dev/null | wc -l | tr -d ' ')"

			if [ "$live_panes" = "$expected_panes" ]; then
				matched="true"
			else
				local backoff_ms=200 cumulative_ms=0
				while [ "$cumulative_ms" -lt "$retry_budget_ms" ]; do
					sleep "$(awk -v ms="$backoff_ms" 'BEGIN { printf "%.3f", ms / 1000 }')"
					cumulative_ms=$((cumulative_ms + backoff_ms))
					restore_all_panes
					expected_panes="$(\grep -c $'^pane\t' "$RESTORE_LAYOUT_FILE" 2>/dev/null)"
					live_panes="$(tmux list-panes -s -t "$session" 2>/dev/null | wc -l | tr -d ' ')"
					if [ "$live_panes" = "$expected_panes" ]; then
						matched="true"
						break
					fi
					backoff_ms=$((backoff_ms * 2))
				done
			fi

			# Runs once regardless of how many restore_all_panes attempts it
			# took above - best effort even if panes are still missing after
			# exhausting the budget, rather than leaving window properties/
			# processes/zoom entirely unset on top of an already-degraded session.
			restore_structure_properties
			cleanup_restored_pane_contents
			execute_hook "post-restore-all"

			if [ "$matched" = "true" ]; then
				:
			else
				any_failed="true"
				failed_sessions+=("$session")
			fi
		fi
	done

	# Focus (which pane/window/session was active) needs a real attached
	# client to restore (switch-client) - restore it now if one already
	# exists, or defer to the moment one actually attaches if not. See
	# restore_focus_for_all_saved_sessions for why and how.
	if [ "$any_saved" = "true" ]; then
		if tmux list-clients 2>/dev/null | \grep -q .; then
			restore_focus_for_all_saved_sessions
		else
			tmux set-hook -g client-attached \
				"run-shell \"$CURRENT_DIR/restore.sh _deferred_focus_restore quiet\"" 2>/dev/null
		fi
	fi

	if [ "$any_failed" = "true" ]; then
		echo "tmux-persist: restore all - gave up on ${#failed_sessions[@]} session(s) that never matched their saved pane count: ${failed_sessions[*]}" >&2
	fi

	if [ "$RESTORE_QUIET" != "true" ]; then
		if [ "$any_saved" != "true" ]; then
			display_message "No saved tmux-persist sessions found!"
		elif [ "$any_failed" = "true" ]; then
			display_message "Tmux restore complete (some sessions failed to verify)!"
		else
			display_message "Tmux restore complete (all sessions)!"
		fi
	fi
}

# Restores which pane/window/session had focus for every saved session,
# without re-restoring structure - structure is assumed already restored
# (e.g. by a prior restore_all_sessions() call in this same bulk pass).
# Re-extracts each session's permanent snapshot rather than relying on the
# earlier bulk pass's staging area, since that's already been cleaned up
# (cleanup_restored_pane_contents) by the time this runs.
#
# This is what restore_all_sessions() calls directly if a client is already
# attached, or installs as a one-shot client-attached hook to call later if
# not: the three focus-restoring functions below all need a real attached
# client to mean anything (they use switch-client), and there usually isn't
# one yet at bulk restore's own trigger points (tmux startup, a scheduled
# job, tmux-continuum's boot-restore). When invoked via the hook, removes
# the hook as its first action, so it only ever runs once - a later
# reattach, after the user has manually changed focus, must not silently
# revert it back to what was saved.
restore_focus_for_all_saved_sessions() {
	tmux set-hook -gu client-attached 2>/dev/null
	local session
	while IFS= read -r session; do
		[ -n "$session" ] || continue
		snapshot_valid "$session" || continue
		RESTORE_SESSION="$session"
		snapshot_extract "$session"
		RESTORE_LAYOUT_FILE="$(snapshot_layout_file "restore")"
		[ -f "$RESTORE_LAYOUT_FILE" ] || continue
		restore_active_pane_for_each_window
		restore_active_and_alternate_windows_for_all_grouped_sessions
		restore_active_and_alternate_windows
		cleanup_restored_pane_contents
	done < <(all_saved_session_names)
}

main() {
	supported_tmux_version_ok || return
	if [ "$RESTORE_DEFERRED_FOCUS" = "true" ]; then
		restore_focus_for_all_saved_sessions
	elif [ "$RESTORE_ALL" = "true" ]; then
		restore_all_sessions
	else
		restore_one_session
	fi
}
main
