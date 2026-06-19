# Automatic saving and restoring

`tmux-persist` installs a few tmux hooks so you rarely have to think about
saving or restoring. Both behaviors are **enabled by default**.

## Auto-save on exit

Sessions are saved automatically when:

- a client **detaches** (`prefix + d`),
- a client **disconnects** (terminal closed / connection dropped),
- a session is **closed** (`Ctrl-d` out of the last pane).

This is wired with the `client-detached` and `session-closed` tmux hooks. On
detach/disconnect the session is still alive, so its full contents are captured.
On `Ctrl-d` the session being torn down can no longer be captured, so it keeps
its most recent snapshot (the auto-save from the previous detach or your last
manual save).

Disable it with:

    set -g @persist-save-on-exit 'off'

## Auto-restore on session creation

When a session is created, its saved contents are restored automatically (using
the `session-created` hook). Create a session named like a saved one and it
comes back with its windows, panes and pane contents:

    tmux new -s my-project

Sessions with no saved snapshot are left untouched and produce no message.

Disable it with:

    set -g @persist-auto-restore 'off'

## Manual save and restore

The key bindings still work and act on the **current** session only:

- `prefix + Ctrl-s` — save the session you are attached to
- `prefix + Ctrl-r` — restore the session you are attached to

To restore a specific session by name from the shell:

    $ ~/path/to/tmux-persist/scripts/restore.sh <session-name>
