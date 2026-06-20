# Save & Restore Hooks

Hooks allow to set custom commands that will be executed during session save
and restore. Most hooks are called with zero arguments, unless explicitly
stated otherwise.

Currently the following hooks are supported:

- `@persist-hook-post-save-layout`

  Called after all sessions, panes and windows have been saved.

  Passed single argument of the state file.

- `@persist-hook-post-save-all`

  Called at end of save process right before the spinner is turned off.

- `@persist-hook-pre-restore-all`

  Called before any tmux state is altered.

- `@persist-hook-pre-restore-pane-processes`

  Called before running processes are restored.

### Examples

Here is an example how to save and restore window geometry for most terminals in X11.
Add this to `.tmux.conf`:

    set -g @persist-hook-post-save-all 'eval $(xdotool getwindowgeometry --shell $WINDOWID); echo 0,$X,$Y,$WIDTH,$HEIGHT > $HOME/.tmux/persist/geometry'
    set -g @persist-hook-pre-restore-all 'wmctrl -i -r $WINDOWID -e $(cat $HOME/.tmux/persist/geometry)'
