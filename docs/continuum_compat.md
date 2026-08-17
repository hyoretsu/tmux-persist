# tmux-continuum compatibility

[tmux-continuum](https://github.com/tmux-plugins/tmux-continuum) adds two
things on top of tmux-resurrect-family plugins: while a client is attached,
it invokes a save every few minutes automatically, independent of
`@persist-save-on-exit`'s detach/close hooks; and, if enabled, it restores
the whole saved environment right after the tmux server starts. It finds
the scripts to invoke via two legacy option names, `@resurrect-save-script-path`
and `@resurrect-restore-script-path`, which `tmux-persist` now sets for it.

## Why a wrapper, not `save.sh` directly

continuum always invokes the script with exactly one argument: `quiet`. It
never passes `all`. That was fine against the original tmux-resurrect, whose
`save.sh` saved every session unconditionally no matter what arguments it
got. `tmux-persist`'s `save.sh` is per-session: bare `quiet` (no explicit
session, no `all`) saves only `#{client_session}` - whichever session the
attached client happens to be in.

Pointed straight at `save.sh`, continuum's periodic tick would therefore
silently narrow to just one session - the one you're currently looking at -
forever, while every other session gets none of continuum's protection. That
would look like it's working (snapshots do get written, on schedule) while
quietly not covering what you'd expect from "automatic periodic saving of
your tmux environment."

`scripts/continuum_save_compat.sh` avoids this: it ignores whatever argument
continuum passes and always calls `save.sh quiet all` - the same flag
`@persist-save-on-exit`'s own hooks already use, for the same reason (no
single "current session" to scope to).

## Why restore needs a wrapper too

continuum invokes `@resurrect-restore-script-path` directly, with no
arguments at all, right after the tmux server starts - before any session
exists yet to provide a `#{client_session}` fallback, and before any client
is attached. `restore.sh`'s own bare invocation (no session, no `all`)
resolves its target session via `#{client_session}`, which has nothing to
resolve at that point - pointed straight at `restore.sh`, continuum's
boot-time restore would fail outright.

`scripts/continuum_restore_compat.sh` avoids this the same way the save-side
wrapper does: it ignores that there are no arguments to work with and always
calls `restore.sh quiet all`.

This also relies on `restore.sh all` (`restore_all_sessions()`) deliberately
skipping active/last window and pane selection, which needs a real attached
client (`tmux switch-client`) that doesn't exist yet at continuum's
boot-restore trigger point - every session, window and pane still comes
back, you just land on each window's default pane rather than whichever one
was focused when it was saved. See
[restoring a previously saved environment](restoring_previously_saved_environment.md)
for the full detail on that trade-off.

## What this does and doesn't give you

With this, installing `tmux-continuum` alongside `tmux-persist` restores
both of its automatic behaviors: periodic *save* (every session, on
continuum's own timer, independent of `@persist-save-on-exit`'s hook-based
triggers) and boot-time *restore* (every saved session, landing on each
window's default pane rather than whichever one was focused - see above).

Also worth knowing: continuum's periodic timer is implemented as a shell
command embedded in tmux's `status-right` format string, so it only executes
while a client is attached and the status line is actually rendering. It
does not run with nothing attached anywhere - that's a structural property
of how continuum triggers itself, not something this wrapper changes.

## If you're running tmux-resurrect and tmux-persist side by side

`@resurrect-save-script-path` and `@resurrect-restore-script-path` are both
set unconditionally on every load, with no option to opt out. For the
overwhelming majority of setups (migrating from tmux-resurrect to
tmux-persist, or never having used tmux-resurrect at all) that's harmless -
neither is a namespace either plugin's users configure by hand. If you
deliberately run both plugins together and rely on tmux-resurrect's own
values for these options, tmux-persist will silently overwrite them on
every load. This is an accepted, narrow limitation rather than something
worth adding a config knob for, given how unlikely that
combination is - open an issue if it affects you in practice.
