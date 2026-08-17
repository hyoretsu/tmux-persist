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

## Restoring everything at once

If you've lost the whole tmux server (a crash, a reboot, `tmux kill-server`)
and want every saved session back, not just one, run the restore script with
`all` instead of a session name:

    $ ~/path/to/tmux-persist/scripts/restore.sh all

This recreates every session that has a saved snapshot - sessions, windows,
panes, working directories, layout and foreground processes - in one pass.
It's the bulk counterpart to `scripts/save.sh all`, which
`@persist-save-on-exit`'s hooks already use for the same reason (no single
"current session" to target).

One thing it deliberately skips: which pane/window has focus in each
restored session. That needs a real attached client (`switch-client`), which
usually doesn't exist yet at the point you'd run this - right after starting
a fresh, otherwise-empty tmux server. Every session, window and pane still
comes back; you just land on each window's default pane rather than
whichever one was focused when it was saved.

There's no key binding for this (same as `save.sh all`, which is also
script/hook-only) - run it directly, or wire it into your own tmux startup
if you want it automatic.

Here are the steps to restore a session to a previous point in time:

- `$ cd ~/.tmux/persist/`
- locate the snapshot you'd like to use for restore (file names have a timestamp)
- point the session's `last` symlink at it: `$ ln -sf <session>_<timestamp>.txt <session>_last`
- create a session with that name and do a restore with the `tmux-persist` key:
  `prefix + Ctrl-r`

You should now be restored to the time when that snapshot was saved.
