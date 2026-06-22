if [ -d "$HOME/.tmux/persist" ]; then
        default_persist_dir="$HOME/.tmux/persist"
elif [ -d "$HOME/.tmux/resurrect" ]; then
        # legacy tmux-resurrect directory, used if no persist dir exists yet
        default_persist_dir="$HOME/.tmux/resurrect"
elif [ -d "${XDG_DATA_HOME:-$HOME/.local/share}/tmux/resurrect" ]; then
        default_persist_dir="${XDG_DATA_HOME:-$HOME/.local/share}"/tmux/resurrect
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
	local option_value="$(tmux show-option -gqv "$option")"
	if [ -z "$option_value" ]; then
		# Backward compatibility: honor the old tmux-resurrect option name
		# (e.g. @resurrect-dir) when its @persist- equivalent is unset.
		case "$option" in
			@persist-*) option_value="$(tmux show-option -gqv "@resurrect-${option#@persist-}")" ;;
		esac
	fi
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

# Strips trailing lines that are only escape sequences and/or whitespace (e.g.
# the blank prompt redraw left after exiting a shell with Ctrl-d). Lines that are
# kept keep their escapes; interior blank lines are preserved.
strip_trailing_blank_lines() {
	awk -v esc="$(printf '\033')" '
		function visible(s) {
			gsub(esc "\\[[0-9;?]*[ -/]*[@-~]", "", s)   # CSI escapes (colors, cursor moves)
			gsub(esc "\\][^\007]*\007", "", s)           # OSC escapes (e.g. window titles)
			gsub(/[ \t]+$/, "", s)
			return s
		}
		{ lines[NR] = $0; if (visible($0) != "") last = NR }
		END { for (i = 1; i <= last; i++) print lines[i] }
	'
}

# Like strip_trailing_blank_lines, but also drops the trailing idle shell prompt.
# A restored pane runs "cat <file>; exec <shell>": the shell redraws its own
# prompt, so any prompt left in the captured file shows up as a duplicate above
# the live one. Worse, the saved prompts arrive on restore as the *output* of that
# cat - so the next capture re-saves them as scrollback and they pile up into a
# tall stack of identical empty prompts that never goes away (a multi-line prompt
# like starship's box just looked like a growing run of blank lines).
#
# Lines are compared by their letters only (see key()): nothing about a specific
# prompt theme is hardcoded - box-drawing glyphs, the prompt symbol, padding and
# the clock are all disregarded, so this works for any prompt, not just starship.
#
# Phase A takes the bottom prompt block as a template and peels off every copy of
# it stacked above:
#   * the block height H is the trailing run of non-blank lines when that run is
#     blank-bounded and no taller than a prompt (MAXH); else the shortest period
#     (1..MAXP) the run repeats with (an already-stacked capture); else 1.
#   * the template is the letter-key of each of those H lines.
#   then drop trailing blocks (skipping blank separators) whose keys match the
#   template, walking up until a block doesn't match. An empty prompt has an empty
#   input-line key; a prompt carrying a no-output command (e.g. "touch a.txt")
#   keeps that command in its key, so it differs and is never erased.
# Phase B then collapses any multi-line prompt stack newly exposed underneath -
# a run that is fully periodic with period >=2 and at least two repeats. This is
# what heals a stack left under a bash "exit" line after a Ctrl-d/EOF, where the
# extra line keeps phase A's template from matching the stack directly.
# Requiring a multi-line repeat (>=2 distinct keys) keeps output safe: a numbered
# list ("out-1", "out-2", ...) has one repeating key and so is never collapsed.
# Call this when the pane's trailing content is a prompt (see pane_prompt_at_bottom).
strip_trailing_prompt() {
	awk -v esc="$(printf '\033')" -v MAXP=6 -v MAXH=4 '
		function visible(s) {
			gsub(esc "\\[[0-9;?]*[ -/]*[@-~]", "", s)
			gsub(esc "\\][^\007]*\007", "", s)
			gsub(/[ \t]+$/, "", s)
			return s
		}
		# Per-line key: the letters only. Box-drawing, the prompt glyph, spaces and
		# the clock are dropped, so two empty prompts compare equal despite a varying
		# clock or a flaky right border - but a prompt with a typed command (whose
		# output was empty, e.g. "touch a.txt") keeps that command in its key and so
		# is NOT mistaken for an empty prompt to be peeled.
		function key(s,  v) { v = visible(s); gsub(/[^a-zA-Z]/, "", v); return v }
		{ lines[NR] = $0; kk[NR] = key($0); if (visible($0) != "") last = NR }
		END {
			if (last < 1) exit                              # nothing but blanks

			# trailing run of non-blank lines, and whether a blank line bounds it.
			run0 = last
			while (run0 > 1 && visible(lines[run0 - 1]) != "") run0--
			runlen = last - run0 + 1

			# height H of the bottom prompt block.
			period = 0
			for (h = 1; h <= MAXP && h < runlen; h++) {
				ok = 1
				for (k = 0; k < h; k++) {
					a = last - k; b = last - h - k
					if (b < run0 || kk[a] != kk[b]) { ok = 0; break }
				}
				if (ok) { period = h; break }
			}
			if (run0 > 1 && runlen <= MAXH) H = runlen       # blank-bounded single prompt
			else if (period > 0) H = period                  # already-stacked capture
			else H = 1                                       # lone/one-line prompt

			# template = letter-key of each line of the bottom block.
			for (i = 0; i < H; i++) tmpl[i] = kk[last - i]

			# Phase A: peel every trailing block whose letter-keys match the template.
			while (1) {
				while (last >= 1 && visible(lines[last]) == "") last--   # skip blank separators
				if (last < H) break
				m = 1
				for (i = 0; i < H; i++) if (kk[last - i] != tmpl[i]) { m = 0; break }
				if (!m) break
				last -= H
			}

			# Phase B: collapse any multi-line prompt stack now exposed (fully
			# periodic, period >=2, at least two repeats).
			while (1) {
				while (last >= 1 && visible(lines[last]) == "") last--
				if (last < 1) break
				r0 = last
				while (r0 > 1 && visible(lines[r0 - 1]) != "") r0--
				rl = last - r0 + 1
				p = 0
				for (h = 2; h <= MAXP && h * 2 <= rl; h++) {
					ok = 1
					for (k = 0; k < rl - h; k++) {
						if (kk[last - k] != kk[last - h - k]) { ok = 0; break }
					}
					# require >=2 distinct keys in one period, so a run of same-prefix
					# output ("out-1", "out-2", ...) is not mistaken for a stack; a real
					# multi-line prompt varies (e.g. box top "system" vs empty input).
					if (ok) {
						delete seen; distinct = 0
						for (k = 0; k < h; k++) if (!(kk[last - k] in seen)) { seen[kk[last - k]] = 1; distinct++ }
						if (distinct < 2) ok = 0
					}
					if (ok) { p = h; break }
				}
				if (p == 0) break
				last = r0 - 1
			}

			for (j = 1; j <= last; j++) print lines[j]
			# If real content survived, leave one blank line after it so the prompt
			# the restored shell redraws sits below a gap instead of jammed against
			# the last line of output.
			if (last >= 1) print ""
		}
	'
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

# Per-session sidecar storing the content hash of the latest snapshot, sibling
# to the "<session>_last" symlink (e.g. "<session>_last.hash"). Used to skip
# writing duplicate snapshots when content is unchanged.
snapshot_hash_file() {
	echo "$(last_session_file "$1").hash"
}

# Reads stdin and prints a content hash. Prefers sha1sum, then shasum (macOS),
# falling back to POSIX cksum so the suite has no hard dependency on coreutils.
hash_stdin() {
	if command -v sha1sum >/dev/null 2>&1; then
		sha1sum | cut -d' ' -f1
	elif command -v shasum >/dev/null 2>&1; then
		shasum | cut -d' ' -f1
	else
		cksum | cut -d' ' -f1
	fi
}

# Content hash of a staging tree (./layout + ./pane_contents/). Independent of
# file mtimes and pane-file order, so identical session state hashes identically
# across saves. Pane filenames are folded in so a pane remap counts as a change.
snapshot_content_hash() {
	local staging="$1"
	{
		printf 'layout\0'
		cat "$staging/layout" 2>/dev/null
		printf '\0'
		if [ -d "$staging/pane_contents" ]; then
			find "$staging/pane_contents" -type f 2>/dev/null | LC_ALL=C sort |
				while IFS= read -r f; do
					printf '%s\0' "${f#"$staging"/}"
					cat "$f"
					printf '\0'
				done
		fi
	} | hash_stdin
}

# Writes the staged ./layout (+ ./pane_contents/) out as a snapshot, in the
# configured format, and points the session's "last" symlink at it.
snapshot_create() {
	local session="$1"
	local primary="$(session_file_path "$session")"
	local staging="$(persist_dir)/save"
	local hash_file="$(snapshot_hash_file "$session")"
	local new_hash="$(snapshot_content_hash "$staging")"

	# Skip writing a duplicate snapshot when content matches the latest one.
	# Refresh the existing snapshot's mtime so age-based pruning keeps it alive,
	# and leave the "last" pointer untouched.
	if [ "$(get_tmux_option "$skip_unchanged_option" "$default_skip_unchanged")" = "on" ]; then
		local last="$(last_session_file "$session")"
		if [ -e "$last" ] && [ "$new_hash" = "$(cat "$hash_file" 2>/dev/null)" ]; then
			local target="$(readlink "$last")"
			touch -h "$last" 2>/dev/null
			touch "$(persist_dir)/$target" 2>/dev/null
			local companion="$(persist_dir)/$(snapshot_companion_file "$target")"
			[ -f "$companion" ] && touch "$companion"
			return
		fi
	fi

	if [ "$(snapshot_format)" = "separate" ]; then
		cp "$staging/layout" "$primary"
		if [ -n "$(find "$staging/pane_contents" -type f -print 2>/dev/null | head -1)" ]; then
			tar czf "$(snapshot_companion_file "$primary")" -C "$staging" ./pane_contents
		fi
	else
		tar czf "$primary" -C "$staging" .
	fi
	ln -fs "$(basename "$primary")" "$(last_session_file "$session")"
	printf '%s\n' "$new_hash" > "$hash_file"
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
		rm -f "$last_link" "$(snapshot_hash_file "$session")"
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

# Permanently removes a session's saved snapshots: every "<session>_<ts>.<ext>"
# primary, its "_pane_contents.tgz" companion, and the "<session>_last" pointer.
# The exact-shape timestamp glob (????????T??????) deletes only this session -
# never a differently-named one that merely shares a prefix. (tmux-resurrect#552,
# #466, #385)
delete_session() {
	local session="$1"
	[ -n "$session" ] || return 1
	shopt -s nullglob
	local snapshot
	for snapshot in "$(persist_dir)/${session}_"????????T??????"."* ; do
		rm -f "$snapshot" "$(snapshot_companion_file "$snapshot")"
	done
	rm -f "$(last_session_file "$session")"
}

# One-time migration of a tmux-resurrect global snapshot (a single
# "tmux_resurrect_<ts>.txt" plus a shared "pane_contents.tar.gz") into per-session
# tmux-persist snapshots. Idempotent via a marker file; never clobbers a session
# that already has a tmux-persist snapshot.
migrate_legacy_snapshots() {
	local dir="$(persist_dir)"
	local flag="$dir/.migrated_from_resurrect"
	[ -f "$flag" ] && return

	# Newest old global snapshot: the "last" symlink, else the latest by name.
	shopt -s nullglob
	local old_file="" f
	if [ -e "$dir/last" ]; then
		old_file="$dir/last"
	else
		for f in "$dir/tmux_resurrect_"*.txt; do old_file="$f"; done
	fi
	[ -n "$old_file" ] && [ -e "$old_file" ] || return

	# Unpack the shared pane-contents archive once (old name scheme: pane-<id>).
	local work="$dir/.migrate"
	rm -rf "$work"; mkdir -p "$work"
	[ -f "$dir/pane_contents.tar.gz" ] &&
		gzip -d < "$dir/pane_contents.tar.gz" | tar xf - -C "$work" 2>/dev/null

	local sessions session pc
	sessions="$(awk -F'\t' '($1=="pane"||$1=="window"){print $2}' "$old_file" 2>/dev/null | sort -u)"
	while IFS= read -r session; do
		[ -n "$session" ] || continue
		[ -e "$(last_session_file "$session")" ] && continue   # keep existing persist snapshot

		rm -rf "$dir/save"; mkdir -p "$dir/save"
		awk -F'\t' -v s="$session" \
			'($1=="pane"||$1=="window"||$1=="grouped_session") && $2==s' \
			"$old_file" > "$dir/save/layout"
		for pc in "$work/pane_contents/pane-${session}:"*; do
			mkdir -p "$dir/save/pane_contents"
			cp "$pc" "$dir/save/pane_contents/"
		done
		snapshot_create "$session"
	done <<EOF
$sessions
EOF

	rm -rf "$work" "$dir/save"
	touch "$flag"
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
