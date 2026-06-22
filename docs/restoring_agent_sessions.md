# Restoring AI agent CLI sessions

AI coding agent CLIs cannot be resumed by re-launching the bare process: each
conversation lives behind a session id, and a fresh launch starts an empty one.
`tmux-persist` restores them through its normal
[restore strategy](restoring_programs.md) mechanism, so no hooks, sidecar
files, or extra dependencies are involved.

The following agents are restored **by default** — each is in the default
process list and registered to the `session` strategy, so there is nothing to
configure:

| Agent | Process | Resume form used |
|---|---|---|
| [Claude Code](https://docs.claude.com/en/docs/claude-code) | `claude` | `claude --continue` |
| [Codex CLI](https://github.com/openai/codex) | `codex` | `codex resume --last` |
| [GitHub Copilot CLI](https://docs.github.com/copilot/how-tos/use-copilot-agents/use-copilot-cli) | `copilot` | `copilot --continue` |
| [Cursor CLI](https://cursor.com/docs/cli/overview) | `cursor-agent` | `cursor-agent --continue` |
| [Antigravity](https://antigravity.google/docs/cli-using) | `agy` | `agy --continue` |
| [Gemini CLI](https://geminicli.com/docs/cli/session-management/) | `gemini` | `gemini --resume` |
| [opencode](https://opencode.ai/docs/cli/) | `opencode` | `opencode --continue` |

## How it works

On restore, each agent's strategy rewrites the captured command into that CLI's
own "resume the most recent conversation here" form. Examples:

| Saved command | Restored command |
|---|---|
| `claude` | `claude --continue` |
| `claude --model opus` | `claude --model opus --continue` |
| `claude --continue` / `claude -r <id>` | unchanged |
| `codex` / `codex fix the bug` | `codex resume --last` |
| `codex resume <id>` / `codex fork <id>` | unchanged |
| `copilot` | `copilot --continue` |
| `cursor-agent` | `cursor-agent --continue` |
| `cursor-agent resume` | unchanged |
| `agy` | `agy --continue` |
| `agy --conversation=<id>` | unchanged |
| `gemini` | `gemini --resume` |
| `opencode` | `opencode --continue` |
| `opencode --session <id>` | unchanged |

Each rewrite asks the CLI to reopen the most recent conversation for the pane's
working directory. An explicit resume the user already typed — a `--resume` /
`--continue` / `-r` / `-c` flag, a `resume` / `fork` subcommand, or an agent's
`--conversation` / `--session` id — is always left untouched, so a deliberately
pinned session wins.

## Disabling

To restore only some of them, override the process list:

    set -g @persist-processes 'claude codex'   # these two only

Or point a single agent's strategy elsewhere / clear it:

    set -g @persist-strategy-gemini ''

## Limitation: multiple panes, same directory

"Most recent conversation here" is keyed by working directory. If several panes
ran the same agent in the *same* directory, they all resume to the single
newest conversation; the others are not individually re-targeted. Pinning a
pane with an explicit by-id resume (e.g. `claude --resume <id>`,
`codex resume <id>`, `agy --conversation=<id>`) before saving avoids the
collapse, because the explicit command is preserved verbatim.

Per-pane session capture would need each CLI to expose its running session id
externally (so save time could record it). Until then the CLI's own
"continue last" form is the dependency-free behavior that is correct for the
common one-agent-per-directory case.
