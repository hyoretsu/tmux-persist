# Restoring pane contents

This plugin saves and restores tmux pane contents (the visual command
history of each pane).

**This feature is enabled by default.** Each pane's contents are saved to
its own file, keyed by session name, so every session's panes are restored
with their own content — no cross-session mixups.

To disable it, add this line to `.tmux.conf`:

    set -g @persist-capture-pane-contents 'off'

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
