# Restoring previously saved environment

Each session is saved separately. The files for a session named `foo` look
like this (one timestamped snapshot per save, plus a `foo_last` symlink to the
most recent one and a `foo_pane_contents.tar.gz` archive):

    foo_20260619T184107.txt
    foo_20260619T184108.txt
    foo_last -> foo_20260619T184108.txt
    foo_pane_contents.tar.gz

None of the previous saves are deleted (unless you explicitly do that). All save
files are kept in `~/.tmux/persist/` directory, or `~/.local/share/tmux/persist`
(unless `${XDG_DATA_HOME}` says otherwise).<br/>

`prefix + Ctrl-r` restores the session you are currently attached to. To restore
a specific session by name, run the restore script with the session as an
argument:

    $ ~/path/to/tmux-persist/scripts/restore.sh foo

Here are the steps to restore a session to a previous point in time:

- `$ cd ~/.tmux/persist/`
- locate the snapshot you'd like to use for restore (file names have a timestamp)
- point the session's `last` symlink at it: `$ ln -sf <session>_<timestamp>.txt <session>_last`
- create a session with that name and do a restore with the `tmux-persist` key:
  `prefix + Ctrl-r`

You should now be restored to the time when that snapshot was saved.
