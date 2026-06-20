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

# strip_trailing_prompt: also drops the trailing idle prompt so a restored shell
# does not duplicate it. Mirrors a starship 2-line prompt (blank separator from
# add_newline + box top + input line) sitting below the last real output.
star="real-output
hello

${esc}[34m╭─ /tmp ─╮${esc}[0m
${esc}[34m╰─ ─╯${esc}[0m"
star_out="$(printf '%s\n' "$star" | strip_trailing_prompt)"
assert_eq       "$(printf '%s\n' "$star_out" | tail -1)" "hello" "starship prompt block dropped (down to last output)"
assert_contains "$star_out" "real-output" "history above the prompt kept"
assert_not_contains "$star_out" "╭─" "prompt box top removed"
assert_not_contains "$star_out" "╰─" "prompt input line removed"

# one-line prompt with an add_newline blank separator
oneline="last-cmd-output

${esc}[36m\$ ${esc}[0m"
oneline_out="$(printf '%s\n' "$oneline" | strip_trailing_prompt)"
assert_eq "$(printf '%s\n' "$oneline_out" | tail -1)" "last-cmd-output" "one-line prompt + add_newline dropped"

# one-line prompt with NO blank separator: only the input line is dropped (the
# preceding real output is preserved, never trimmed past it)
nosep="keep-me-1
keep-me-2
${esc}[36m\$ ${esc}[0m"
nosep_out="$(printf '%s\n' "$nosep" | strip_trailing_prompt)"
assert_eq       "$(printf '%s\n' "$nosep_out" | tail -1)" "keep-me-2" "no-separator prompt: only input line dropped"
assert_contains "$nosep_out" "keep-me-1" "no-separator prompt: earlier output kept"

# an accumulated STACK of empty prompts (each save/restore cycle piled one on)
# collapses entirely - down to the real output above it. The box top carries a
# volatile clock, so the lines are not byte-identical; matching is structural.
stack="real-output

${esc}[34m╭─ /tmp ✔ 14:15:48 ─╮${esc}[0m
${esc}[34m╰─ ─╯${esc}[0m
${esc}[34m╭─ /tmp ✔ 14:16:24 ─╮${esc}[0m
${esc}[34m╰─ ─╯${esc}[0m
${esc}[34m╭─ /tmp ✔ 15:17:22 ─╮${esc}[0m
${esc}[34m╰─ ─╯${esc}[0m"
stack_out="$(printf '%s\n' "$stack" | strip_trailing_prompt)"
assert_eq       "$(printf '%s\n' "$stack_out" | tail -1)" "real-output" "prompt stack collapses to last real output"
assert_not_contains "$stack_out" "╭─" "no stacked prompt box survives"

# a whole capture that is nothing but a prompt stack collapses to empty
allstack="${esc}[34m╭─ a 14:15:48 ─╮${esc}[0m
${esc}[34m╰─ ─╯${esc}[0m
${esc}[34m╭─ a 14:16:24 ─╮${esc}[0m
${esc}[34m╰─ ─╯${esc}[0m"
assert_eq "$(printf '%s\n' "$allstack" | strip_trailing_prompt)" "" "all-prompt capture yields empty"

# the real post-restore shape: a cat-restored stack arrives as scrollback (so it
# is *above* the live prompt, separated by the add_newline blank). The whole thing
# must still collapse, else the stack is immortal across save/restore cycles.
embedded="${esc}[34m╭─ a 14:15:48 ─╮${esc}[0m
${esc}[34m╰─ ─╯${esc}[0m
${esc}[34m╭─ a 14:16:24 ─╮${esc}[0m
${esc}[34m╰─ ─╯${esc}[0m

${esc}[34m╭─ a 15:30:01 ─╮${esc}[0m
${esc}[34m╰─ ❯ ─╯${esc}[0m"
assert_eq "$(printf '%s\n' "$embedded" | strip_trailing_prompt)" "" "cat-restored stack below the live prompt also collapses"

# real output must NOT be trimmed just because it is several non-blank lines
# running up to the prompt (no blank separator): only the cursor line goes.
longout="out-1
out-2
out-3
out-4
out-5
${esc}[36m\$ ${esc}[0m"
longout_out="$(printf '%s\n' "$longout" | strip_trailing_prompt)"
assert_contains "$longout_out" "out-1" "long output: first line kept"
assert_eq       "$(printf '%s\n' "$longout_out" | tail -1)" "out-5" "long output: only cursor line dropped"

# Ctrl-d/EOF: bash prints "exit" below the prompt as it leaves. The trailing
# prompt + that line must go, keeping the real work above.
eof="realwork-out

${esc}[34m╭─ box ─╮${esc}[0m
${esc}[34m╰─ ❯ ${esc}[0m
exit"
assert_eq "$(printf '%s\n' "$eof" | strip_trailing_prompt | grep . | tail -1)" "realwork-out" "EOF prompt + bash 'exit' line dropped"

# EOF on top of an existing stack: the extra "exit" line shifts the bottom block,
# but phase B still collapses the periodic stack underneath.
eofstack="real-output

${esc}[34m╭─ a 14:00 ─╮${esc}[0m
${esc}[34m╰─ ─╯${esc}[0m
${esc}[34m╭─ a 14:01 ─╮${esc}[0m
${esc}[34m╰─ ─╯${esc}[0m

${esc}[34m╭─ box ─╮${esc}[0m
${esc}[34m╰─ ❯ ${esc}[0m
exit"
assert_eq "$(printf '%s\n' "$eofstack" | strip_trailing_prompt | grep . | tail -1)" "real-output" "EOF over a stack heals down to real output"

# a numbered list shares a leading char but is not a prompt stack - never eaten.
numbered="item-1
item-2
item-3
item-4

${esc}[34m╭─ box ─╮${esc}[0m
${esc}[34m╰─ ❯ ${esc}[0m"
numbered_out="$(printf '%s\n' "$numbered" | strip_trailing_prompt)"
assert_contains "$numbered_out" "item-1" "numbered list: first item kept"
assert_eq       "$(printf '%s\n' "$numbered_out" | tail -1)" "item-4" "numbered list: not collapsed by phase B"

# when content survives, a trailing blank line is emitted so the restored prompt
# sits below a gap (use wc -l, since $() would strip the trailing newline).
gap="$(printf '%s\n' "kept-line

${esc}[34m╭─ box ─╮${esc}[0m
${esc}[34m╰─ ❯ ${esc}[0m" | strip_trailing_prompt | wc -l)"
assert_eq "$(echo $gap)" "2" "trailing blank line added after surviving content"
# but an all-prompt capture stays empty (no leading blank on restore).
gap0="$(printf '%s\n' "${esc}[34m╭─ a 14:00 ─╮${esc}[0m
${esc}[34m╰─ ─╯${esc}[0m
${esc}[34m╭─ a 14:01 ─╮${esc}[0m
${esc}[34m╰─ ─╯${esc}[0m" | strip_trailing_prompt | wc -c)"
assert_eq "$(echo $gap0)" "0" "no blank line when nothing survives"

finish
