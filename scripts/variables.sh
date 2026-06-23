# key bindings
default_save_key="C-s"
save_option="@persist-save"
save_path_option="@persist-save-script-path"

default_restore_key="C-r"
restore_option="@persist-restore"
restore_path_option="@persist-restore-script-path"

# default processes that are restored
default_proc_list_option="@persist-default-processes"
default_proc_list='vi vim view nvim emacs man less more tail top htop irssi weechat mutt claude codex copilot cursor-agent agy gemini opencode'

# User defined processes that are restored
#  'false' - nothing is restored
#  ':all:' - all processes are restored
#
# user defined list of programs that are restored:
#  'my_program foo another_program'
restore_processes_option="@persist-processes"
restore_processes=""

# Defines part of the user variable. Example usage:
#   set -g @persist-strategy-vim "session"
restore_process_strategy_option="@persist-strategy-"

inline_strategy_token="->"
inline_strategy_arguments_token="*"

save_command_strategy_option="@persist-save-command-strategy"
default_save_command_strategy="ps"

# Pane contents capture options.
# Capturing pane contents (visual command history) is enabled by default.
# Each pane's contents are saved to its own file, keyed by session, so panes
# are always restored per session. Set '@persist-capture-pane-contents' to
# 'off' to disable.
# @persist-pane-contents-area option can be:
#   'visible' - capture only the visible pane area
#   'full'    - capture the full pane contents
pane_contents_option="@persist-capture-pane-contents"
default_pane_contents="on"
pane_contents_area_option="@persist-pane-contents-area"
default_pane_contents_area="full"

# set to 'on' to ensure panes are never ever overwritten
overwrite_option="@persist-never-overwrite"

# Hooks are set via ${hook_prefix}${name}, i.e. "@persist-hook-post-save-all"
hook_prefix="@persist-hook-"

# Snapshots older than this many days are erased automatically (on save and on
# server start). When all of a session's snapshots expire, its "last" pointer
# and pane-contents archive are removed too.
delete_backup_after_option="@persist-delete-backup-after"
default_delete_backup_after="7" # days

# Keep at most this many snapshots per session (the newest ones). Older extras
# are erased regardless of age. 0 means unlimited (only age-based pruning).
max_snapshots_option="@persist-max-snapshots"
default_max_snapshots="0"

# How a snapshot stores its layout and pane contents:
#   'together'  - one file per snapshot, "<session>_<timestamp>.tgz"
#   'separate'  - layout "<session>_<timestamp>.txt" plus a companion
#                 "<session>_<timestamp>_pane_contents.tgz"
# Restore auto-detects the format from the files, so this only affects new saves.
snapshot_format_option="@persist-snapshot-format"
default_snapshot_format="together"

# Skip writing a new snapshot when a session's content (layout + pane contents)
# is byte-identical to its latest snapshot. The existing snapshot's mtime is
# refreshed instead, so age-based pruning keeps it alive without piling up
# duplicate files on every detach. Set to 'off' to always write a new snapshot.
skip_unchanged_option="@persist-skip-unchanged"
default_skip_unchanged="on"

# Automatically save when a client detaches or a session is closed. This covers
# detaching (prefix + d), disconnecting (terminal closed) and exiting a session
# (Ctrl-d out of the last pane). Set to 'off' to disable.
save_on_exit_option="@persist-save-on-exit"
default_save_on_exit="on"

# Automatically restore a session's saved contents when a session with that name
# is created. Set to 'off' to disable.
auto_restore_option="@persist-auto-restore"
default_auto_restore="on"

# Save sessions that have no explicit name. tmux names an unnamed session with a
# number (0, 1, 2, ...), so these are throwaway sessions whose numeric name will
# not match anything on restore. Skipped by default; set to 'on' to save them.
save_unnamed_option="@persist-save-unnamed"
default_save_unnamed="off"

# Internal marker (set per server) so the one-time restore of sessions that
# already exist when the plugin loads runs only once, not on every reload.
initialized_option="@persist-initialized"
