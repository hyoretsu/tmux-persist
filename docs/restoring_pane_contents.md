# Restoring pane contents

This plugin saves and restores tmux pane contents (the visual command
history of each pane).

**This feature is enabled by default.** Pane contents are stored as part of
each session's snapshot, so every session is restored with its own content —
no cross-session mixups.

To disable it, add this line to `.tmux.conf`:

    set -g @persist-capture-pane-contents 'off'

## What a snapshot contains

Each save writes a per-session snapshot, named with a timestamp
(`<session>_<timestamp>.…`). A snapshot holds two things:

- **layout** — one tab-separated record per pane and per window: session name,
  window index, pane index, working directory, pane title, the running program
  and its full command line, window name/layout, active/zoomed flags, and (for
  "grouped" sessions) the grouping. This is what recreates the windows, panes,
  splits and programs.
- **pane contents** — for each pane, the text captured with `tmux capture-pane`
  (the visible scrollback, i.e. the on-screen command history). This is what
  `cat`s back into each pane on restore. There is no separate shell-history
  ($HISTFILE) capture — "pane contents" is exactly what was on screen.

### Storage format

By default layout and pane contents live **together** in a single file per
snapshot (`<session>_<timestamp>.tgz`). You can store them **separately**
instead — a `<session>_<timestamp>.txt` layout plus a
`<session>_<timestamp>_pane_contents.tgz` companion:

    set -g @persist-snapshot-format 'separate'   # default: 'together'

Restore auto-detects the format from the files on disk, so snapshots saved
either way always restore.

##### Known issue

When using this feature, please check the value of `default-command`
tmux option. That can be done with `$ tmux show -g default-command`.

The value should NOT contain `&&` or `||` operators. If it does, simplify the
option so those operators are removed.

Example:

- this will cause issues (notice the `&&` and `||` operators):

        set -g default-command "which reattach-to-user-namespace > /dev/null && reattach-to-user-namespace -l $SHELL || $SHELL -l"

- this is ok:

        set -g default-command "reattach-to-user-namespace -l $SHELL"

Related [bug](https://github.com/tmux-plugins/tmux-persist/issues/98).

Alternatively, you can let
[tmux-sensible](https://github.com/tmux-plugins/tmux-sensible)
handle this option in a cross-platform way and you'll have no problems.
