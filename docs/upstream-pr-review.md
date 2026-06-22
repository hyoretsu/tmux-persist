# Upstream PR Review (tmux-resurrect → tmux-persist)

Tracks which open [tmux-resurrect](https://github.com/tmux-plugins/tmux-resurrect)
pull requests have been evaluated against this fork, the verdict, and what (if
anything) the fork adopted. Companion to [`upstream-triage.md`](upstream-triage.md),
which covers upstream *issues*.

| PR | Title | Reviewed | Verdict | Outcome in fork |
|---|---|---|---|---|
| [#558](https://github.com/tmux-plugins/tmux-resurrect/pull/558) | Add Claude Code and Codex CLI session restore | 2026-06-22 | **Adopted (base)** | Ported `claude`/`codex` `session` strategies + default-list wiring + tests. See [`restoring_agent_sessions.md`](restoring_agent_sessions.md). |
| [#571](https://github.com/tmux-plugins/tmux-resurrect/pull/571) | Restore claude sessions via `--resume <id>` | 2026-06-22 | Rejected | Heavy: needs a `SessionStart` hook, `python3`, and manual `settings.json` edits for per-pane mapping; its basic mode hand-reads `~/.claude/projects/*.jsonl` instead of using `claude --continue`. Per-pane correctness noted as a [known limitation](restoring_agent_sessions.md#limitation-multiple-panes-same-directory). |
| [#572](https://github.com/tmux-plugins/tmux-resurrect/pull/572) | Resurrect `copilot`, `agy`, `codex` CLIs | 2026-06-22 | Rejected (mechanism) | One large pre-save hook that fuzzy-matches pane text against app SQLite DBs (`session-store.db`, `state_5.sqlite`) and process logs; author-flagged "vibe-coded", no tests, fragile across CLI/DB-schema changes. Its target CLIs are instead covered by clean `session` strategies: `copilot --continue`, `agy --continue`, `codex resume --last`. See [`restoring_agent_sessions.md`](restoring_agent_sessions.md). |

## Why #558 over #571 / #572

- **Framework-native.** #558 uses the existing per-process restore-strategy
  mechanism (`strategies/<cmd>_session.sh` + `@persist-strategy-<cmd>`), the same
  path `vim`/`nvim` use. #571 and #572 bolt on out-of-band machinery (settings
  hooks, sqlite reads, pane-text scraping).
- **No external dependencies.** No `python3`, no `sqlite3`, no per-session
  sidecar files, no edits to the agents' own config.
- **Tested + deterministic.** Pure command rewrite, covered by
  [`tests/test_agent_strategies.sh`](../tests/test_agent_strategies.sh).
- **Resilient.** Defers to each CLI's own resume (`claude --continue`,
  `codex resume --last`) rather than depending on an on-disk layout or DB schema
  that can change without notice.

### Improvements over #558 as merged

- Resume detection also recognizes claude's short flags `-c` / `-r`, with
  whole-token matching so a `--continue` inside a prompt argument can't trip it.
- Wired as fork defaults via `persist.tmux` `set_default_strategies` and the
  `@persist-` option namespace (not the upstream `@resurrect-` names).
- Extended the same dependency-free pattern beyond #558's claude/codex to the
  other famous agent CLIs that expose a "continue last" command: `copilot`,
  `cursor-agent` (Cursor), `agy` (Antigravity), `gemini`, `opencode`. Agents
  without such a command (e.g. aider, which auto-restores from in-repo history)
  are intentionally left out.
