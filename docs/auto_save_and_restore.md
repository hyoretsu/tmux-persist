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

Disable it with:

    set -g @persist-save-on-exit 'off'

### Saving on `Ctrl-d` (shell integration)

`Ctrl-d` is special. It makes the shell exit, which closes the pane and then the
session. By the time tmux fires `pane-exited` / `session-closed`, the pane is
already gone — its contents can no longer be captured. So the auto-save hooks
alone leave a `Ctrl-d`-closed session with only its most recent snapshot (the
last detach or manual save).

To save *at the moment of* `Ctrl-d`, save from the shell just before it exits,
while the pane is still alive. This only saves; it does not change what `Ctrl-d`
does. Add to your shell rc:

zsh (`~/.zshrc`):

    if [ -n "$TMUX" ]; then
      zshexit() {
        local script; script="$(tmux show-option -gqv @persist-save-script-path)"
        [ -n "$script" ] && "$script" quiet "$(tmux display-message -p '#{client_session}')" >/dev/null 2>&1
      }
    fi

bash (`~/.bashrc`):

    if [ -n "$TMUX" ]; then
      _persist_save_on_exit() {
        local script; script="$(tmux show-option -gqv @persist-save-script-path)"
        [ -n "$script" ] && "$script" quiet "$(tmux display-message -p '#{client_session}')" >/dev/null 2>&1
      }
      trap _persist_save_on_exit EXIT
    fi

`@persist-save-script-path` is set by the plugin, so you don't have to hardcode
the path.

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
