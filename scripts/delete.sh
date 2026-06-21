#!/usr/bin/env bash

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

source "$CURRENT_DIR/variables.sh"
source "$CURRENT_DIR/helpers.sh"

# Arguments (any order):
#   quiet      - produce no output (used by hooks)
#   <session>  - delete this session's snapshots instead of the current one
# Without a session argument the session the client is attached to is deleted.
DELETE_SESSION=""
DELETE_QUIET="false"
for arg in "$@"; do
	case "$arg" in
		quiet) DELETE_QUIET="true" ;;
		*) DELETE_SESSION="$arg" ;;
	esac
done
if [ -z "$DELETE_SESSION" ]; then
	DELETE_SESSION="$(tmux display-message -p "#{client_session}")"
fi

main() {
	if supported_tmux_version_ok; then
		delete_session "$DELETE_SESSION"
		[ "$DELETE_QUIET" = "true" ] || display_message "Saved session '${DELETE_SESSION}' deleted!"
	fi
}
main
