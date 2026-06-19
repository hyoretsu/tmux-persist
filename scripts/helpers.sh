if [ -d "$HOME/.tmux/persist" ]; then
        default_persist_dir="$HOME/.tmux/persist"
else
        default_persist_dir="${XDG_DATA_HOME:-$HOME/.local/share}"/tmux/persist
fi
persist_dir_option="@persist-dir"

SUPPORTED_VERSION="1.9"
PERSIST_FILE_EXTENSION="txt"
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

pane_contents_create_archive() {
	local session="$1"
	tar cf - -C "$(persist_dir)/save/" ./pane_contents/ |
		gzip > "$(pane_contents_archive_file "$session")"
}

pane_content_files_restore_from_archive() {
	local session="$1"
	local archive_file="$(pane_contents_archive_file "$session")"
	if [ -f "$archive_file" ]; then
		mkdir -p "$(pane_contents_dir "restore")"
		gzip -d < "$archive_file" |
			tar xf - -C "$(persist_dir)/restore/"
	fi
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

# Per-session layout snapshot, e.g. "<persist-dir>/cubari_20260619T182833.txt".
# The session name is the file's prefix so each session is stored separately.
session_file_path() {
	local session="$1"
	echo "$(persist_dir)/${session}_${_PERSIST_TIMESTAMP}.${PERSIST_FILE_EXTENSION}"
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

# Per-session pane-contents archive, e.g. "<persist-dir>/cubari_pane_contents.tar.gz".
pane_contents_archive_file() {
	local session="$1"
	echo "$(persist_dir)/${session}_pane_contents.tar.gz"
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
