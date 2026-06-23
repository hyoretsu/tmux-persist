#!/usr/bin/env bash
# Unnamed (numeric-named) sessions are throwaway and must not be saved by
# default; opting in with @persist-save-unnamed re-enables saving them.

source "$(dirname "$0")/helpers/test_helpers.sh"
setup

# A session created without -s gets a numeric tmux name (0, 1, 2, ...).
unnamed="$(tmuxp new-session -dP -F '#{session_name}')"
assert_eq "$(printf '%s' "$unnamed" | grep -cE '^[0-9]+$')" "1" \
	"new-session without -s is numeric-named ($unnamed)"

# --- default: unnamed session is skipped ---
save all
assert_no_file "$TEST_PERSIST_DIR/${unnamed}_"*.tgz "unnamed session not saved by default"
assert_no_file "$TEST_PERSIST_DIR/${unnamed}_last" "no last pointer for unnamed session"

# --- named session alongside it is still saved ---
make_session proj PROJ_MARK
save all
assert_file "$TEST_PERSIST_DIR/proj_"*.tgz "named session saved"

# --- opt in: now the unnamed session is saved too ---
tmuxp set -g @persist-save-unnamed on
save all
assert_file "$TEST_PERSIST_DIR/${unnamed}_"*.tgz "unnamed session saved when opted in"

teardown
finish
