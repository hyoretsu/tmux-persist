#!/usr/bin/env bash
# strip_trailing_blank_lines: trailing escape-only / whitespace-only lines are
# dropped (the Ctrl-d prompt-redraw gap), kept lines and interior blanks stay.

source "$(dirname "$0")/helpers/test_helpers.sh"
# shellcheck source=/dev/null
source "$PLUGIN_DIR/scripts/variables.sh"
# shellcheck source=/dev/null
source "$PLUGIN_DIR/scripts/helpers.sh"

esc="$(printf '\033')"

input="line1
${esc}[32mcolored${esc}[0m

trailing-real
${esc}[34m   ${esc}[0m
   "

out="$(printf '%s\n' "$input" | strip_trailing_blank_lines)"

assert_eq        "$(printf '%s\n' "$out" | tail -1)" "trailing-real" "trailing escape/whitespace lines dropped"
assert_contains  "$out" "line1"   "first line kept"
assert_contains  "$out" "colored" "colored line kept (escapes preserved)"
assert_contains  "$out" "$esc"    "escape sequences preserved in kept lines"
assert_eq        "$(printf '%s\n' "$out" | grep -c '^$')" "1" "interior blank line preserved"

# all-blank input collapses to nothing
empty_out="$(printf '%s\n' "   ${esc}[0m
   " | strip_trailing_blank_lines)"
assert_eq "$empty_out" "" "all-blank input yields empty output"

finish
