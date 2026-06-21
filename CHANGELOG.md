# Changelog

### Unreleased

- Saves whose content is byte-identical to a session's latest snapshot no longer
  write a duplicate file; the existing snapshot's mtime is refreshed instead so
  age-based pruning keeps it alive. This keeps auto-save-on-detach from piling up
  identical snapshots. Toggle with `@persist-skip-unchanged` (default `on`).

### v5.1.0, 2026-06-20

- Restored panes no longer pile up duplicate shell prompts. The trailing prompt is
  stripped from saved pane contents, and snapshots already bloated by earlier
  versions clean themselves up on the next save. Works with any prompt, keeps your
  commands and their output, and applies whether you detach or exit with
  `Ctrl-d`.

### v5.0.0, 2026-06-20

First release of the `tmux-persist` fork. Upgrading from tmux-resurrect needs no
changes: existing config keeps working and saved data is migrated automatically.

- Automatically migrates a tmux-resurrect global snapshot
  (`tmux_resurrect_<ts>.txt` + shared `pane_contents.tar.gz`) into per-session
  tmux-persist snapshots on first load. Runs once, never overwrites an existing
  persist snapshot.
- Backward compatible with tmux-resurrect config: any unset `@persist-*` option
  falls back to its old `@resurrect-*` name, and the legacy `~/.tmux/resurrect`
  (or `$XDG_DATA_HOME/tmux/resurrect`) directory is used if no persist dir
  exists. Old options still work but are deprecated (a one-time notice advises
  renaming them).
- CI moved from Travis to GitHub Actions; the test suite runs on every pull
  request (and on demand via workflow_dispatch).
- Disabling `@persist-save-on-exit` / `@persist-auto-restore` now removes the
  corresponding tmux hooks (previously toggling off left them active until the
  server restarted).
- Replaced the old tmux-test/expect tests with a self-contained suite
  (`./tests/run.sh`) covering per-session save/restore, capture-by-default,
  save-all, auto-restore on creation, age/cap/expiry/collision pruning, and the
  together/separate snapshot formats. Dropped the `tmux-test` submodule.
- Pane contents are now stored **inside each snapshot** instead of one shared
  per-session archive, so historical snapshots keep their own contents. New
  `@persist-snapshot-format` chooses how: `together` (default; one
  `<session>_<timestamp>.tgz`) or `separate` (a `.txt` layout plus a
  `_pane_contents.tgz` companion). Restore auto-detects the format.
- Added `@persist-max-snapshots` to cap how many snapshots each session keeps
  (newest kept; default `0` = unlimited). Composes with age-based pruning.
- Snapshot retention is now purely age-based: snapshots older than
  `@persist-delete-backup-after` days (default **7**, was 30 with a 5-copy
  floor) are erased automatically on save and on server start. When all of a
  session's snapshots expire, its `last` pointer and pane-contents archive are
  removed too. Pruning is collision-safe (`a` never affects `a_b`).
- Renamed the project to `tmux-persist`; tmux options are now `@persist-*` and
  the default save directory is `~/.tmux/persist` (or
  `$XDG_DATA_HOME/tmux/persist`).
- Pane-contents capture is now **enabled by default** (set
  `@persist-capture-pane-contents 'off'` to disable).
- **Auto-save on exit.** Sessions are saved automatically on the
  `client-detached` and `session-closed` tmux hooks (covers detaching,
  disconnecting and exiting). Disable with `@persist-save-on-exit 'off'`.
- **Per-session save and restore.** Each session is now saved to its own files
  named `<session>_*` (`<session>_<timestamp>.txt`, `<session>_last`,
  `<session>_pane_contents.tar.gz`) instead of one shared `last` /
  `tmux_resurrect_*.txt` / `pane_contents.tar.gz`. Restore acts on the session
  you are attached to (or a session name passed to `restore.sh`) and no longer
  recreates or switches to other sessions — fixing the bug where restoring one
  session pulled in another's panes/contents.

### v4.0.0, 2022-04-10
- Proper handling of `automatic-rename` window option.
- save and restore tmux pane title (breaking change: you have to re-save to be
  able to properly restore!)

### v3.0.0, 2021-08-30
- save and restore tmux pane contents (@laomaiweng)
- update tmux-test to solve issue with recursing git submodules in that project
- set options quietly in `persist.tmux` script
- improve pane contents restoration: `cat <file>` is no longer shown in pane
  content history
- refactoring: drop dependency on `paste` command
- bugfix for pane contents restoration
- expand tilde char `~` if used with `@persist-dir`
- do not save empty trailing lines when pane content is saved
- do not save pane contents if pane is empty (only for 'save pane contents'
  feature)
- "save pane contents" feature saves files to a separate directory
- archive and compress pane contents file
- make archive & compress pane contents process more portable
- `mutt` added to the list of automatically restored programs
- added guide for migrating from tmuxinator
- fixed a bug for restoring commands on tmux 2.5 (and probably tmux 2.4)
- do not create another persist file if there are no changes (credit @vburdo)
- allow using '$HOSTNAME' in @persist-dir
- add zsh history saving and restoring
- delete persist files older than 30 days, but keep at least 5 files
- add save and restore hooks
- always use `-ao` flags for `ps` command to detect commands
- Deprecate restoring shell history feature.
- `view` added to the list of automatically restored programs
- Enable vim session strategy to work with custom session files,
  e.g. `vim -S Session1.vim`.
- Enable restoring command arguments for inline strategies with `*` character.
- Kill session "0" if it wasn't restored.
- Add `@persist-delete-backup-after` option to specify how many days of
  backups to keep - default is 30.

### v2.4.0, 2015-02-23
- add "tmux-test"
- add test for "persist save" feature
- add test for "persist restore" feature
- make the tests work and pass on travis
- add travis badge to the readme

### v2.3.0, 2015-02-12
- Improve fetching proper window_layout for zoomed windows. In order to fetch
  proper value, window has to get unzoomed. This is now done faster so that
  "unzoom,fetch value,zoom" cycle is almost unnoticable to the user.

### v2.2.0, 2015-02-12
- bugfix: zoomed windows related regression
- export save and restore script paths so that 'tmux-persist-save' plugin can
  use them
- enable "quiet" saving (used by 'tmux-persist-save' plugin)

### v2.1.0, 2015-02-12
- if restore is started when there's only **1 pane in the whole tmux server**,
  assume the users wants the "full restore" and overrwrite that pane.

### v2.0.0, 2015-02-10
- add link to the wiki page for "first pane/window issue" to the README as well
  as other tweaks
- save and restore grouped sessions (used with multi-monitor workflow)
- save and restore active and alternate windows in grouped sessions
- if there are no grouped sessions, do not output empty line to "last" file
- restore active and alternate windows only if they are present in the "last" file
- refactoring: prefer using variable with tab character
- remove deprecated `M-s` and `M-r` key bindings (breaking change)

### v1.5.0, 2014-11-09
- add support for restoring neovim sessions

### v1.4.0, 2014-10-25
- plugin now uses strategies when fetching pane full command. Implemented
  'default' strategy.
- save command strategy: 'pgrep'. It's here only if fallback is needed.
- save command strategy: 'gdb'
- rename default strategy name to 'ps'
- create `expect` script that can fully restore tmux environment
- fix default save command strategy `ps` command flags. Flags are different for
  FreeBSD.
- add bash history saving and restoring (@rburny)
- preserving layout of zoomed windows across restores (@Azrael3000)

### v1.3.0, 2014-09-20
- remove dependency on `pgrep` command. Use `ps` for fetching process names.

### v1.2.1, 2014-09-02
- tweak 'new_pane' creation strategy to fix #36
- when running multiple tmux server and for a large number of panes (120 +) when
  doing a restore, some panes might not be created. When that is the case also
  don't restore programs for those panes.

### v1.2.0, 2014-09-01
- new feature: inline strategies when restoring a program

### v1.1.0, 2014-08-31
- bugfix: sourcing `variables.sh` file in save script
- add `Ctrl` key mappings, deprecate `Alt` keys mappings.

### v1.0.0, 2014-08-30
- show spinner during the save process
- add screencast script
- make default program running list even more conservative

### v0.4.0, 2014-08-29
- change plugin name to `tmux-persist`. Change all the variable names.

### v0.3.0, 2014-08-29
- bugfix: when top is running the pane `$PWD` can't be saved. This was causing
  issues during the restore and is now fixed.
- restoring sessions multiple times messes up the whole environment - new panes
  are all around. This is now fixed - pane restorations are now idempotent.
- if pane exists from before session restore - do not restore the process within
  it. This makes the restoration process even more idempotent.
- more panes within a window can now be restored
- restore window zoom state

### v0.2.0, 2014-08-29
- bugfix: with vim 'session' strategy, if the session file does not exist - make
  sure vim does not contain `-S` flag
- enable restoring programs with arguments (e.g. "rails console") and also
  processes that contain program name
- improve `irb` restore strategy

### v0.1.0, 2014-08-28
- refactor checking if saved tmux session exists
- spinner while tmux sessions are restored

### v0.0.5, 2014-08-28
- restore pane processes
- user option for disabling pane process restoring
- enable whitelisting processes that will be restored
- expand readme with configuration options
- enable command strategies; enable restoring vim sessions
- update readme: explain restoring vim sessions

### v0.0.4, 2014-08-26
- restore pane layout for each window
- bugfix: correct pane ordering in a window

### v0.0.3, 2014-08-26
- save and restore current and alternate session
- fix a bug with non-existing window names
- restore active pane for each window that has multiple panes
- restore active and alternate window for each session

### v0.0.2, 2014-08-26
- saving a new session does not remove the previous one
- make the directory where sessions are stored configurable
- support only Tmux v1.9 or greater
- display a nice error message if saved session file does not exist
- added README

### v0.0.1, 2014-08-26
- started a project
- basic saving and restoring works
