#!/usr/bin/env bash
# Compatibility target for tmux-continuum's boot-time restore. See
# docs/continuum_compat.md for what this gets you and its caveats.
#
# tmux-continuum invokes "$resurrect_restore_script_path" directly, with no
# arguments, right after the tmux server starts - before any session exists
# yet to provide a "#{client_session}" fallback and before any client is
# attached. restore.sh's own bare invocation (no session, no "all") resolves
# the target session via "tmux display-message -p #{client_session}", which
# has nothing to resolve at that point. This wrapper always asks restore.sh
# for every saved session instead, the same way continuum_save_compat.sh
# always asks save.sh for every session regardless of what continuum passes.

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
exec "$CURRENT_DIR/restore.sh" quiet all
