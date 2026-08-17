#!/usr/bin/env bash
# Compatibility target for tmux-continuum's periodic autosave. See
# docs/continuum_compat.md for the full explanation of why this exists
# instead of just pointing continuum straight at save.sh.
#
# tmux-continuum always invokes "$resurrect_save_script_path" "quiet" - never
# "all" - because it was built against the original tmux-resurrect, whose
# save.sh saved every session unconditionally regardless of arguments.
# tmux-persist's save.sh is per-session: bare "quiet" (no explicit session,
# no "all") scopes to whichever session the attached client happens to be
# in. Passed continuum's call unmodified, that would silently narrow every
# periodic "keep everything safe" tick to just one session - the one you're
# currently looking at - forever, while every other session gets none of
# continuum's protection. This wrapper ignores whatever continuum passes and
# always asks save.sh for every session instead.

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
exec "$CURRENT_DIR/save.sh" quiet all
