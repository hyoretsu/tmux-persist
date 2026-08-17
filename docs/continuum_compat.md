# tmux-continuum compatibility

[tmux-continuum](https://github.com/tmux-plugins/tmux-continuum) adds a
periodic save timer and boot-time restore on top of tmux-resurrect-family
plugins. Both work with tmux-persist automatically - install both plugins,
no configuration needed.

## What you get

- Every session gets saved on continuum's own timer, independent of
  `@persist-save-on-exit`'s detach/close hooks.
- Every saved session gets restored automatically when tmux starts, if
  `@continuum-restore` is on.

## Caveats

- Boot-time restore doesn't restore which pane/window had focus - that
  needs a real attached client, which doesn't exist yet at that point.
  Every session, window and pane still comes back; you just land on each
  window's default pane. See
  [restoring a previously saved environment](restoring_previously_saved_environment.md).
- continuum's periodic save only runs while a client is attached and the
  status line is actually rendering - it can't cover a stretch where
  nothing is attached anywhere. See
  [tmux-persist-autosave](https://github.com/theredspoon/tmux-persist-autosave)
  if you need that covered too.
- If you deliberately run tmux-resurrect and tmux-persist side by side
  (both installed, not just migrating from one to the other):
  tmux-persist claims continuum's legacy option names
  (`@resurrect-save-script-path`, `@resurrect-restore-script-path`)
  unconditionally on every load and will silently overwrite
  tmux-resurrect's own values for them. Open an issue if this affects you.
