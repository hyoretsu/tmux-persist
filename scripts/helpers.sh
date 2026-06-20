if [ -d "$HOME/.tmux/persist" ]; then
        default_persist_dir="$HOME/.tmux/persist"
else
        default_persist_dir="${XDG_DATA_HOME:-$HOME/.local/share}"/tmux/persist
fi
persist_dir_option="@persist-dir"

SUPPORTED_VERSION="1.9"
_PERSIST_DIR=""

d=$'\t'

# helper functions
get_tmux_option() {
	local option="$1"
	local default_value="$2"
	local option_value=$(tmux show-option -gqv "$option")
	if [ -z "$option_value" ]; then
		echo "$default_value"
	else
		echo "$option_value"
	fi
}

# Ensures a message is displayed for 5 seconds in tmux prompt.
# Does not override the 'display-time' tmux option.
display_message() {
	local message="$1"

	# display_duration defaults to 5 seconds, if not passed as an argument
	if [ "$#" -eq 2 ]; then
		local display_duration="$2"
	else
		local display_duration="5000"
	fi

	# saves user-set 'display-time' option
	local saved_display_time=$(get_tmux_option "display-time" "750")

	# sets message display time to 5 seconds
	tmux set-option -gq display-time "$display_duration"

	# displays message
	tmux display-message "$message"

	# restores original 'display-time' value
	tmux set-option -gq display-time "$saved_display_time"
}


supported_tmux_version_ok() {
	$CURRENT_DIR/check_tmux_version.sh "$SUPPORTED_VERSION"
}

remove_first_char() {
	echo "$1" | cut -c2-
}

capture_pane_contents_option_on() {
	local option="$(get_tmux_option "$pane_contents_option" "$default_pane_contents")"
	[ "$option" == "on" ]
}

files_differ() {
	! cmp -s "$1" "$2"
}

get_grouped_sessions() {
	local grouped_sessions_dump="$1"
	export GROUPED_SESSIONS="${d}$(echo "$grouped_sessions_dump" | cut -f2 -d"$d" | tr "\\n" "$d")"
}

is_session_grouped() {
	local session_name="$1"
	[[ "$GROUPED_SESSIONS" == *"${d}${session_name}${d}"* ]]
}

# pane content file helpers

# A snapshot stores a session's layout and (optionally) its pane contents. Two
# on-disk formats share one interface, selected by @persist-snapshot-format:
#   together  - one file: "<session>_<timestamp>.tgz" holding ./layout and
#               ./pane_contents/
#   separate  - "<session>_<timestamp>.txt" (layout) plus a companion
#               "<session>_<timestamp>_pane_contents.tgz" (pane contents)
# Saving/staging always happens under "<persist-dir>/{save,restore}/" as a
# ./layout file and a ./pane_contents/ dir; only snapshot_create/snapshot_extract
# know the format. Restore detects the format from the files, so a snapshot saved
# either way always restores.

snapshot_format() {
	get_tmux_option "$snapshot_format_option" "$default_snapshot_format"
}

# File extension of the primary snapshot file for a new save.
snapshot_extension() {
	if [ "$(snapshot_format)" = "separate" ]; then echo "txt"; else echo "tgz"; fi
}

snapshot_layout_file() {
	# $1 = save | restore
	echo "$(persist_dir)/$1/layout"
}

# Companion pane-contents file for a separate-format snapshot, derived from the
# primary file path: "<...>_<ts>.txt" -> "<...>_<ts>_pane_contents.tgz".
snapshot_companion_file() {
	echo "${1%.*}_pane_contents.tgz"
}

# Writes the staged ./layout (+ ./pane_contents/) out as a snapshot, in the
# configured format, and points the session's "last" symlink at it.
snapshot_create() {
	local session="$1"
	local primary="$(session_file_path "$session")"
	local staging="$(persist_dir)/save"
	if [ "$(snapshot_format)" = "separate" ]; then
		cp "$staging/layout" "$primary"
		if [ -n "$(find "$staging/pane_contents" -type f -print 2>/dev/null | head -1)" ]; then
			tar czf "$(snapshot_companion_file "$primary")" -C "$staging" ./pane_contents
		fi
	else
		tar czf "$primary" -C "$staging" .
	fi
	ln -fs "$(basename "$primary")" "$(last_session_file "$session")"
}

# Populates the restore staging area (./layout, ./pane_contents/) from a
# session's latest snapshot, auto-detecting the on-disk format.
snapshot_extract() {
	local session="$1"
	local last="$(last_session_file "$session")"
	rm -rf "$(persist_dir)/restore"
	[ -e "$last" ] || return
	mkdir -p "$(persist_dir)/restore"
	local target="$(readlink "$last")"
	case "$target" in
		*.tgz)
			# together: one tarball with ./layout and ./pane_contents/
			tar xzf "$last" -C "$(persist_dir)/restore" 2>/dev/null
			;;
		*)
			# separate (or a plain layout file): copy the layout, then unpack the
			# companion pane-contents archive if present.
			cp "$last" "$(persist_dir)/restore/layout"
			local companion="$(persist_dir)/$(snapshot_companion_file "$target")"
			[ -f "$companion" ] && tar xzf "$companion" -C "$(persist_dir)/restore" 2>/dev/null
			;;
	esac
}

# path helpers

persist_dir() {
	if [ -z "$_PERSIST_DIR" ]; then
		local path="$(get_tmux_option "$persist_dir_option" "$default_persist_dir")"
		# expands tilde, $HOME and $HOSTNAME if used in @persist-dir
		echo "$path" | sed "s,\$HOME,$HOME,g; s,\$HOSTNAME,$(hostname),g; s,\~,$HOME,g"
	else
		echo "$_PERSIST_DIR"
	fi
}
_PERSIST_DIR="$(persist_dir)"

# A single timestamp shared by every session saved in one save run.
_PERSIST_TIMESTAMP="$(date +"%Y%m%dT%H%M%S")"

# Per-session snapshot file, e.g. "<persist-dir>/cubari_20260619T182833.tgz".
# The session name is the file's prefix so each session is stored separately.
session_file_path() {
	local session="$1"
	echo "$(persist_dir)/${session}_${_PERSIST_TIMESTAMP}.$(snapshot_extension)"
}

# Symlink pointing at the latest snapshot for a session, e.g.
# "<persist-dir>/cubari_last".
last_session_file() {
	local session="$1"
	echo "$(persist_dir)/${session}_last"
}

pane_contents_dir() {
	echo "$(persist_dir)/$1/pane_contents/"
}

pane_contents_file() {
	local save_or_restore="$1"
	local pane_id="$2"
	echo "$(pane_contents_dir "$save_or_restore")/pane-${pane_id}"
}

pane_contents_file_exists() {
	local pane_id="$1"
	[ -f "$(pane_contents_file "restore" "$pane_id")" ]
}

# Erase a session's stale snapshots. A snapshot is removed if it is older than
# @persist-delete-backup-after days, or if it is beyond the newest
# @persist-max-snapshots (0 = unlimited). The timestamp glob is shaped exactly
# (????????T??????) so a session named "a" is never confused with "a_b". If
# every snapshot is removed the "last" symlink ends up dangling, meaning the
# whole session is stale - so its pointer is dropped too.
remove_old_backups() {
	local session="$1"
	local delete_after="$(get_tmux_option "$delete_backup_after_option" "$default_delete_backup_after")"
	local max_snapshots="$(get_tmux_option "$max_snapshots_option" "$default_max_snapshots")"
	shopt -s nullglob
	# Primary snapshot files only ("<session>_<ts>.<ext>"); the exact timestamp
	# glob excludes the "_pane_contents.tgz" companions and never matches "a_b".
	local -a snapshots=( "$(persist_dir)/${session}_"????????T??????"."* )
	# Sort newest first. The filenames share a prefix and end in a sortable
	# timestamp, so a plain reverse string sort is chronological.
	if [ "${#snapshots[@]}" -gt 1 ]; then
		local oldifs="$IFS"; IFS=$'\n'
		snapshots=( $(printf '%s\n' "${snapshots[@]}" | sort -r) )
		IFS="$oldifs"
	fi
	local i=0 snapshot delete
	for snapshot in "${snapshots[@]}"; do
		delete="false"
		# too old?
		[ -n "$(find "$snapshot" -mtime "+${delete_after}" -print 2>/dev/null)" ] && delete="true"
		# beyond the cap? (index 0 is the newest, so the latest is always kept)
		if [ "$max_snapshots" -gt 0 ] 2>/dev/null && [ "$i" -ge "$max_snapshots" ]; then
			delete="true"
		fi
		if [ "$delete" = "true" ]; then
			# remove the primary and its pane-contents companion (if any)
			rm -f "$snapshot" "$(snapshot_companion_file "$snapshot")"
		fi
		i=$((i + 1))
	done
	local last_link="$(last_session_file "$session")"
	if [ -L "$last_link" ] && [ ! -e "$last_link" ]; then
		rm -f "$last_link"
	fi
}

# Runs remove_old_backups for every saved session (one "<session>_last" each).
prune_all_old_backups() {
	shopt -s nullglob
	local link session
	for link in "$(persist_dir)/"*_last; do
		session="$(basename "$link")"
		session="${session%_last}"
		remove_old_backups "$session"
	done
}

execute_hook() {
	local kind="$1"
	shift
	local args="" hook=""

	hook=$(get_tmux_option "$hook_prefix$kind" "")

	# If there are any args, pass them to the hook (in a way that preserves/copes
	# with spaces and unusual characters.
	if [ "$#" -gt 0 ]; then
		printf -v args "%q " "$@"
	fi

	if [ -n "$hook" ]; then
		eval "$hook $args"
	fi
}
