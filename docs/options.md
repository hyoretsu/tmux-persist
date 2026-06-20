# Options reference

Every option is a tmux user option, set in `tmux.conf` with:

    set -g <option> '<value>'

All defaults are sensible — `tmux-persist` needs no configuration. Options are
read live on each save/restore, so `tmux source-file ~/.tmux.conf` applies
changes (key bindings and hooks are (re)installed when the plugin is sourced).

> **Coming from tmux-resurrect:** any unset `@persist-*` option falls back to
> its old `@resurrect-*` name, so existing configs keep working (deprecated).

## Key bindings

| Option | Default | Description |
|---|---|---|
| `@persist-save` | `C-s` | Key (after prefix) that saves the current session. |
| `@persist-restore` | `C-r` | Key (after prefix) that restores the current session. |

Multiple keys can be given, space-separated. See also
[custom key bindings](custom_key_bindings.md).

## What gets restored (programs)

| Option | Default | Description |
|---|---|---|
| `@persist-processes` | `''` | Extra programs to restore. A space-separated list (`'mosh-server irb'`); `':all:'` restores everything; `'false'` restores nothing. |
| `@persist-default-processes` | `vi vim view nvim emacs man less more tail top htop irssi weechat mutt` | The built-in allow-list of programs restored by default. Override to change it. |
| `@persist-strategy-<program>` | — | Per-program restore strategy, e.g. `set -g @persist-strategy-vim 'session'`. |
| `@persist-save-command-strategy` | `ps` | How a pane's full command line is detected at save time. |

See [restoring programs](restoring_programs.md) and
[restoring vim/neovim sessions](restoring_vim_and_neovim_sessions.md).

## Pane contents

| Option | Default | Description |
|---|---|---|
| `@persist-capture-pane-contents` | `on` | Capture each pane's visible scrollback. `'off'` to disable. |
| `@persist-pane-contents-area` | `full` | `'full'` captures the whole history; `'visible'` only the on-screen area. |

See [restoring pane contents](restoring_pane_contents.md).

## Storage & snapshot format

| Option | Default | Description |
|---|---|---|
| `@persist-dir` | `~/.tmux/persist` (or `$XDG_DATA_HOME/tmux/persist`) | Where snapshots are stored. `$HOME`, `$HOSTNAME` and `~` are expanded; see [save dir](save_dir.md). |
| `@persist-snapshot-format` | `together` | `'together'`: one `<session>_<ts>.tgz` per snapshot. `'separate'`: a `<session>_<ts>.txt` layout plus a `<session>_<ts>_pane_contents.tgz`. Restore auto-detects either. |

## Retention

| Option | Default | Description |
|---|---|---|
| `@persist-delete-backup-after` | `7` | Erase snapshots older than this many days (on save and at server start). When a session's last snapshot expires, the session is forgotten entirely. |
| `@persist-max-snapshots` | `0` | Keep at most this many snapshots per session (newest kept). `0` = unlimited. Composes with the age window. |

## Automatic save / restore

| Option | Default | Description |
|---|---|---|
| `@persist-save-on-exit` | `on` | Auto-save on `client-detached` and `session-closed` (detach, disconnect, exit). `'off'` removes the hooks. |
| `@persist-auto-restore` | `on` | Auto-restore a session's contents when a session of that name is created. `'off'` removes the hook. |

See [automatic saving and restoring](auto_save_and_restore.md), which also
covers saving on `Ctrl-d` via shell integration.

## Advanced

| Option | Default | Description |
|---|---|---|
| `@persist-never-overwrite` | `''` | Set to any non-empty value to never overwrite a freshly created single pane during restore (disables the "restore from scratch" overwrite). |
| `@persist-hook-<name>` | — | Run a shell command at a lifecycle point. See [hooks](hooks.md). Points: `post-save-layout`, `post-save-all`, `pre-restore-all`, `pre-restore-pane-processes`, `post-restore-all`. |

## Exposed by the plugin (read-only)

Set automatically so you can reference the scripts from your own bindings/hooks
without hardcoding paths:

| Option | Description |
|---|---|
| `@persist-save-script-path` | Absolute path to `save.sh`. |
| `@persist-restore-script-path` | Absolute path to `restore.sh`. |

## Internal (do not set)

`@persist-initialized` and `@persist-legacy-warned` are per-server markers the
plugin manages itself.
