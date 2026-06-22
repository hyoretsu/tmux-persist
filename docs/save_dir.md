# Persist save dir

By default the Tmux environment is saved under `$XDG_STATE_HOME/tmux/persist`
(i.e. `~/.local/state/tmux/persist`) on a fresh install, since saved sessions
are application *state* per the XDG base-dir spec. Existing locations are still
used when present, in this order: `~/.tmux/persist`, the legacy
`~/.tmux/resurrect`, `$XDG_STATE_HOME/tmux/persist`, the legacy
`$XDG_DATA_HOME/tmux/resurrect`, then `$XDG_DATA_HOME/tmux/persist`.

Change the location with:

    set -g @persist-dir '/some/path'

Using environment variables or shell interpolation in this option is not
allowed as the string is used literally. So the following won't do what is
expected:

    set -g @persist-dir '/path/$MY_VAR/$(some_executable)'

Only the following variables and special chars are allowed:
`$HOME`, `$HOSTNAME`, and `~`.
