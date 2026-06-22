# Restoring AI agent CLI sessions

[Claude Code](https://docs.claude.com/en/docs/claude-code) (`claude`) and
[Codex CLI](https://github.com/openai/codex) (`codex`) cannot be resumed by
re-launching the bare process: each conversation lives behind a session id, and
a fresh launch starts an empty one. `tmux-persist` restores them through its
normal [restore strategy](restoring_programs.md) mechanism, so no hooks,
sidecar files, or extra dependencies are involved.

Both are restored **by default** — `claude` and `codex` are in the default
process list and registered to the `session` strategy. There is nothing to
configure.

## How it works

On restore, each tool's strategy rewrites the captured command into the CLI's
own "resume the most recent conversation here" form:

| Saved command | Restored command |
|---|---|
| `claude` | `claude --continue` |
| `claude --model opus` | `claude --model opus --continue` |
| `claude --continue` / `claude -c` | unchanged |
| `claude --resume <id>` / `claude -r <id>` | unchanged |
| `codex` | `codex resume --last` |
| `codex fix the bug` | `codex resume --last` |
| `codex resume <id>` / `codex fork <id>` | unchanged |

`claude --continue` and `codex resume --last` ask each CLI to reopen the most
recent conversation for the pane's working directory. An explicit
`--resume`/`-r` (claude) or `resume`/`fork` subcommand (codex) the user already
typed is always left untouched, so a deliberately pinned session wins.

## Disabling

To stop restoring one of them, override the process list without it:

    set -g @persist-processes 'claude'   # restore claude only, not codex

Or point its strategy elsewhere / clear it:

    set -g @persist-strategy-codex ''

## Limitation: multiple panes, same directory

"Most recent conversation here" is keyed by working directory. If several panes
ran the same agent in the *same* directory, they all resume to the single
newest conversation; the others are not individually re-targeted. Pinning a
pane with an explicit `claude --resume <id>` / `codex resume <id>` before saving
avoids the collapse, because the explicit command is preserved verbatim.

Per-pane session capture would need each CLI to expose its running session id
externally (so save time could record it). Until then `--continue` /
`resume --last` is the dependency-free behavior that is correct for the common
one-agent-per-directory case.
