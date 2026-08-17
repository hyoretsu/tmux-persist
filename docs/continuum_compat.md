# tmux-continuum compatibility

[tmux-continuum](https://github.com/tmux-plugins/tmux-continuum) adds a
periodic timer on top of tmux-resurrect-family plugins: while a client is
attached, it invokes a save every few minutes automatically, independent of
`@persist-save-on-exit`'s detach/close hooks. It finds the script to invoke
via a legacy option name, `@resurrect-save-script-path`, which `tmux-persist`
now sets for it.

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

## Why restore isn't bridged the same way

`restore.sh` has no `all` equivalent - each session restores separately, by
name (or `#{client_session}` if none is given). continuum's boot-time
restore (`@continuum-boot`/`@continuum-restore`) expects to restore the
*entire* saved environment right after the tmux server starts, before any
session exists yet to provide a `#{client_session}` to fall back to.

Even a hypothetical "restore every saved session" wrapper would run straight
into an existing, unrelated limitation: restoring active/last window and
pane selection uses `tmux switch-client`, which needs a real attached
client - and at continuum's boot-restore trigger point, by design, there
isn't one yet. See #31 for the existing tracking issue; this is upstream of
anything a compat wrapper here could fix.

## What this does and doesn't give you

With this, installing `tmux-continuum` alongside `tmux-persist` restores its
periodic *save* behavior (every session, on continuum's own timer,
independent of `@persist-save-on-exit`'s hook-based triggers). Its automatic
*restore-on-boot* feature remains non-functional for the reasons above.

Also worth knowing: continuum's periodic timer is implemented as a shell
command embedded in tmux's `status-right` format string, so it only executes
while a client is attached and the status line is actually rendering. It
does not run with nothing attached anywhere - that's a structural property
of how continuum triggers itself, not something this wrapper changes.

## If you're running tmux-resurrect and tmux-persist side by side

`@resurrect-save-script-path` is set unconditionally on every load, with no
option to opt out. For the overwhelming majority of setups (migrating from
tmux-resurrect to tmux-persist, or never having used tmux-resurrect at all)
that's harmless - it's not a namespace either plugin's users configure by
hand. If you deliberately run both plugins together and rely on
tmux-resurrect's own value for this option, tmux-persist will silently
overwrite it on every load. This is an accepted, narrow limitation rather
than something worth adding a config knob for, given how unlikely that
combination is - open an issue if it affects you in practice.
