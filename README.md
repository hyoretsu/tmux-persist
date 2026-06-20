# Tmux Persist

[![tests](https://github.com/hyoretsu/tmux-persist/actions/workflows/tests.yml/badge.svg)](https://github.com/hyoretsu/tmux-persist/actions/workflows/tests.yml)

Restore `tmux` environment after system restart.

> `tmux-persist` is a maintained fork of the (abandoned)
> [tmux-resurrect](https://github.com/tmux-plugins/tmux-resurrect). It fixes
> pane-contents capture so each session is saved and restored separately, and
> enables pane-contents capture by default.
>
> Coming from tmux-resurrect? Your config keeps working: unset `@persist-*`
> options fall back to the old `@resurrect-*` names and directory (deprecated -
> rename when convenient). Snapshots saved by tmux-resurrect use the old format,
> though, so save once after switching.

Tmux is great, except when you have to restart the computer. You lose all the
running programs, working directories, pane layouts etc.
There are helpful management tools out there, but they require initial
configuration and continuous updates as your workflow evolves or you start new
projects.

`tmux-persist` saves all the little details from your tmux environment so it
can be completely restored after a system restart (or when you feel like it).
No configuration is required. You should feel like you never quit tmux.

It even (optionally)
[restores vim and neovim sessions](docs/restoring_vim_and_neovim_sessions.md)!

Automatic restoring and continuous saving of tmux env is also possible with
[tmux-continuum](https://github.com/tmux-plugins/tmux-continuum) plugin.

### Screencast

[![screencast screenshot](/video/screencast_img.png)](https://vimeo.com/104763018)

### Key bindings

- `prefix + Ctrl-s` - save the session you are currently attached to
- `prefix + Ctrl-r` - restore the session you are currently attached to

Each session is saved separately to its own files, so save and restore only
ever touch the session you are in — restore never recreates or switches you to
other sessions. To save/restore a specific session by name, run
`scripts/save.sh <session-name>` / `scripts/restore.sh <session-name>`.

Saving and restoring also happen **automatically**: sessions are saved on
detach, disconnect and exit, and restored when a session is (re)created. See
[automatic saving and restoring](docs/auto_save_and_restore.md). Disable with
`@persist-save-on-exit 'off'` / `@persist-auto-restore 'off'`.

### About

This plugin goes to great lengths to save and restore all the details from your
`tmux` environment. Here's what's been taken care of:

- all sessions, windows, panes and their order
- current working directory for each pane
- **exact pane layouts** within windows (even when zoomed)
- active and alternative session
- active and alternative window for each session
- windows with focus
- active pane for each window
- "grouped sessions" (useful feature when using tmux with multiple monitors)
- programs running within a pane! More details in the
  [restoring programs doc](docs/restoring_programs.md).
- **pane contents** (the visual command history of each pane), saved
  separately per session and enabled by default. See
  [restoring pane contents](docs/restoring_pane_contents.md).

Optional:

- [restoring vim and neovim sessions](docs/restoring_vim_and_neovim_sessions.md)
- [restoring a previously saved environment](docs/restoring_previously_saved_environment.md)

Requirements / dependencies: `tmux 1.9` or higher, `bash`.

Tested and working on Linux, OSX and Cygwin.

`tmux-persist` is idempotent! It will not try to restore panes or windows that
already exist.<br/>
The single exception to this is when the session being restored has only 1 pane
(e.g. a freshly created session). Only in this case will that single pane be
overwritten.

### Installation with [Tmux Plugin Manager](https://github.com/tmux-plugins/tpm) (recommended)

Add plugin to the list of TPM plugins in `.tmux.conf`:

    set -g @plugin 'hyoretsu/tmux-persist'

Hit `prefix + I` to fetch the plugin and source it. You should now be able to
use the plugin.

### Manual Installation

Clone the repo:

    $ git clone https://github.com/hyoretsu/tmux-persist ~/clone/path

Add this line to the bottom of `.tmux.conf`:

    run-shell ~/clone/path/persist.tmux

Reload TMUX environment with: `$ tmux source-file ~/.tmux.conf`.
You should now be able to use the plugin.

### Docs

- [Guide for migrating from tmuxinator](docs/migrating_from_tmuxinator.md)

**Configuration**

- [Changing the default key bindings](docs/custom_key_bindings.md).
- [Setting up hooks on save & restore](docs/hooks.md).
- Only a conservative list of programs is restored by default:<br/>
  `vi vim nvim emacs man less more tail top htop irssi weechat mutt`.<br/>
  [Restoring programs doc](docs/restoring_programs.md) explains how to restore
  additional programs.
- [Change a directory](docs/save_dir.md) where `tmux-persist` saves tmux
  environment (`@persist-dir`).
- [Automatic saving and restoring](docs/auto_save_and_restore.md) on detach,
  disconnect, exit and session creation (`@persist-save-on-exit`,
  `@persist-auto-restore`).
- Snapshots older than 7 days are erased automatically. Change the window
  with `set -g @persist-delete-backup-after '<days>'`. When all of a session's
  snapshots expire, the session is forgotten entirely (its `last` pointer and
  pane contents go too).
- Optionally cap how many snapshots each session keeps with
  `set -g @persist-max-snapshots '<n>'` (default `0` = unlimited). Extras beyond
  the newest `n` are erased regardless of age.
- Each snapshot bundles its layout and pane contents in one file by default.
  Store them apart with `set -g @persist-snapshot-format 'separate'`. See
  [restoring pane contents](docs/restoring_pane_contents.md) for what a snapshot
  contains.

**Optional features**

- [Restoring vim and neovim sessions](docs/restoring_vim_and_neovim_sessions.md)
  is nice if you're a vim/neovim user.
- [Restoring pane contents](docs/restoring_pane_contents.md) is enabled by
  default; this doc explains how to tune or disable it.

### Other goodies

- [tmux-copycat](https://github.com/tmux-plugins/tmux-copycat) - a plugin for
  regex searches in tmux and fast match selection
- [tmux-yank](https://github.com/tmux-plugins/tmux-yank) - enables copying
  highlighted text to system clipboard
- [tmux-open](https://github.com/tmux-plugins/tmux-open) - a plugin for quickly
  opening highlighted file or a url
- [tmux-continuum](https://github.com/tmux-plugins/tmux-continuum) - automatic
  restoring and continuous saving of tmux env

### Reporting bugs and contributing

Both contributing and bug reports are welcome. Please check out
[contributing guidelines](CONTRIBUTING.md).

### Credits

[Bruno Sutic](https://github.com/bruno-) and the
[tmux-resurrect](https://github.com/tmux-plugins/tmux-resurrect) contributors -
`tmux-persist` is a fork of their work.

[Mislav Marohnić](https://github.com/mislav) - the idea for the plugin came from his
[tmux-session script](https://github.com/mislav/dotfiles/blob/2036b5e03fb430bbcbc340689d63328abaa28876/bin/tmux-session).

### License
[MIT](LICENSE.md)
