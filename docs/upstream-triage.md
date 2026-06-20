# Upstream Issue Triage (tmux-resurrect → tmux-persist)

`tmux-persist` is a maintained fork of the abandoned
[tmux-resurrect](https://github.com/tmux-plugins/tmux-resurrect). This document
triages **all 229 open** tmux-resurrect issues against the fork's **current
code**, so maintenance can be prioritized.

Issues are sorted into four buckets:

- **A1 — Already fixed / implemented:** the fork made a deliberate change (bug
  fix or new feature) that resolves it. No work.
- **A2 — Not reproducible:** the scenario can no longer occur (the offending
  feature was removed), so the report is moot. No work.
- **B — Reproducible & fixable:** a real defect still present in the fork,
  classified **Easy / Medium / Hard**.
- **C — Not a bug:** questions, feature requests, docs, or by-design limits.

> **Method & caveat.** Reproducibility was judged by **reading the fork's
> code**, not by running each reproduction. Items tagged `(verify)` still need a
> live repro before being closed or fixed. Source scanned: `scripts/save.sh`,
> `scripts/restore.sh`, `scripts/process_restore_helpers.sh`, `persist.tmux`,
> `scripts/helpers.sh`.

## Fork divergences that resolve whole issue classes

- **Per-session save/restore** — restore touches only the attached session; no
  extra session, no focus loss, no cross-session bleed.
- **Auto-save** (`client-detached` / `session-closed`) **+ auto-restore**
  (`session-created`) — "auto restore / restore from CLI / save on detach" all
  resolved.
- **Trailing-prompt / blank-line stripping** (`save.sh` `pane_prompt_at_bottom`,
  `strip_trailing_prompt`) — ghost / duplicate prompts resolved.
- **Shell-history save feature REMOVED** — no `fc` / `history -w/-r` anywhere;
  the entire bash/zsh/fish history class is gone.
- **Age-based pruning + `@persist-max-snapshots`** — file rotation / "too many
  backups" resolved.
- **Pane contents stored inside each per-session snapshot** — historical
  snapshots keep their own contents; the old `pane_contents//pane-…`
  double-slash path is restructured.
- **Window name + `automatic-rename` + per-pane title saved/restored** — name /
  title loss resolved.

---

## Bucket A1 — Already fixed / implemented

The fork made a deliberate bug fix or new feature that resolves these. No work
needed; `(verify)` rows want one live repro before closing.

| Issue(s) | What resolved it |
|---|---|
| [553](https://github.com/tmux-plugins/tmux-resurrect/issues/553), [384](https://github.com/tmux-plugins/tmux-resurrect/issues/384), [360](https://github.com/tmux-plugins/tmux-resurrect/issues/360), [261](https://github.com/tmux-plugins/tmux-resurrect/issues/261), [243](https://github.com/tmux-plugins/tmux-resurrect/issues/243), [181](https://github.com/tmux-plugins/tmux-resurrect/issues/181), [427](https://github.com/tmux-plugins/tmux-resurrect/issues/427), [39](https://github.com/tmux-plugins/tmux-resurrect/issues/39) | per-session save/restore + restore-by-name |
| [524](https://github.com/tmux-plugins/tmux-resurrect/issues/524) | per-session restore creates no extra session |
| [549](https://github.com/tmux-plugins/tmux-resurrect/issues/549), [503](https://github.com/tmux-plugins/tmux-resurrect/issues/503) | trailing-prompt stripping |
| [270](https://github.com/tmux-plugins/tmux-resurrect/issues/270), [139](https://github.com/tmux-plugins/tmux-resurrect/issues/139), [509](https://github.com/tmux-plugins/tmux-resurrect/issues/509), [275](https://github.com/tmux-plugins/tmux-resurrect/issues/275) | auto-restore / `restore.sh <session>` / auto-save on exit |
| [136](https://github.com/tmux-plugins/tmux-resurrect/issues/136) | `@persist-max-snapshots` + age pruning |
| [252](https://github.com/tmux-plugins/tmux-resurrect/issues/252) | retention now 7-day configurable, not hard-coded `-mtime +30` |
| [200](https://github.com/tmux-plugins/tmux-resurrect/issues/200), [117](https://github.com/tmux-plugins/tmux-resurrect/issues/117), [282](https://github.com/tmux-plugins/tmux-resurrect/issues/282), [110](https://github.com/tmux-plugins/tmux-resurrect/issues/110), [260](https://github.com/tmux-plugins/tmux-resurrect/issues/260) (verify) | window/pane name + title now saved & restored |
| [453](https://github.com/tmux-plugins/tmux-resurrect/issues/453) | `pane_title` saved + `select-pane -T` on restore |
| [409](https://github.com/tmux-plugins/tmux-resurrect/issues/409) | contents inside per-snapshot; historical snapshots keep theirs |
| [448](https://github.com/tmux-plugins/tmux-resurrect/issues/448), [538](https://github.com/tmux-plugins/tmux-resurrect/issues/538), [526](https://github.com/tmux-plugins/tmux-resurrect/issues/526) (verify) | per-session snapshot restructured the double-slash contents path |
| [446](https://github.com/tmux-plugins/tmux-resurrect/issues/446), [262](https://github.com/tmux-plugins/tmux-resurrect/issues/262) | per-pane cwd saved (history half also moot — see A2) |
| [463](https://github.com/tmux-plugins/tmux-resurrect/issues/463) | legacy-format migration on load |
| [487](https://github.com/tmux-plugins/tmux-resurrect/issues/487) | test suite rewritten (`tests/run.sh`) |
| [486](https://github.com/tmux-plugins/tmux-resurrect/issues/486), [483](https://github.com/tmux-plugins/tmux-resurrect/issues/483) | `mkdir -p` persist dir + new save hooks |
| [112](https://github.com/tmux-plugins/tmux-resurrect/issues/112) (verify) | save no longer toggles zoom; restore re-applies the `Z` flag |
| [122](https://github.com/tmux-plugins/tmux-resurrect/issues/122), [287](https://github.com/tmux-plugins/tmux-resurrect/issues/287), [339](https://github.com/tmux-plugins/tmux-resurrect/issues/339), [322](https://github.com/tmux-plugins/tmux-resurrect/issues/322) (verify) | from-scratch handling / no blank-save on start / active-window restore |
| [244](https://github.com/tmux-plugins/tmux-resurrect/issues/244) | auto-save on exit (periodic interval is still continuum's job) |

---

## Bucket A2 — Not reproducible

The offending feature was removed, so the reported scenario can no longer occur.
No fix to make; the report is simply moot.

| Issue(s) | Why it can't occur |
|---|---|
| [373](https://github.com/tmux-plugins/tmux-resurrect/issues/373), [359](https://github.com/tmux-plugins/tmux-resurrect/issues/359), [288](https://github.com/tmux-plugins/tmux-resurrect/issues/288), [278](https://github.com/tmux-plugins/tmux-resurrect/issues/278), [303](https://github.com/tmux-plugins/tmux-resurrect/issues/303), [248](https://github.com/tmux-plugins/tmux-resurrect/issues/248), [219](https://github.com/tmux-plugins/tmux-resurrect/issues/219), [217](https://github.com/tmux-plugins/tmux-resurrect/issues/217), [86](https://github.com/tmux-plugins/tmux-resurrect/issues/86) | shell-history save feature removed entirely (no `fc` / `history -w/-r`) |

---

## Bucket B — Reproducible & fixable

### Easy — localized change

| Issue | Bug | Fix sketch |
|---|---|---|
| [561](https://github.com/tmux-plugins/tmux-resurrect/issues/561) | persist dir is world-readable (`mkdir -p`, no chmod) | `chmod 0700` after mkdir in the dir helper |
| [497](https://github.com/tmux-plugins/tmux-resurrect/issues/497) | non-bash login shell not invoked (only bash gets `-l`) | extend `cache_tmux_default_command` `-l` logic to zsh/fish |
| [548](https://github.com/tmux-plugins/tmux-resurrect/issues/548) | a space in `$HOME`/path breaks restore | `dump_panes` `sed 's/ /\\ /'` lacks the `g` flag; escape all spaces + quote the dir |
| [415](https://github.com/tmux-plugins/tmux-resurrect/issues/415) | session named `''` fails to restore | validate / skip empty session name on save |
| [323](https://github.com/tmux-plugins/tmux-resurrect/issues/323) | `vi` not resurrected (only `vim` matches) | add `vi` to the default proc list / vim strategy |
| [485](https://github.com/tmux-plugins/tmux-resurrect/issues/485) | restore into a deleted dir silently lands in `$HOME` | fall back to nearest existing parent (optionally create) |

### Medium — moderate, one subsystem

| Issue(s) | Bug | Area |
|---|---|---|
| [543](https://github.com/tmux-plugins/tmux-resurrect/issues/543) | window number taken from previous server | `new_session` base-index / move-window |
| [563](https://github.com/tmux-plugins/tmux-resurrect/issues/563), [492](https://github.com/tmux-plugins/tmux-resurrect/issues/492), [65](https://github.com/tmux-plugins/tmux-resurrect/issues/65) | stacked / minimal / uneven panes after restore | `new_pane` `resize -U 999` hack vs `select-layout` ordering |
| [438](https://github.com/tmux-plugins/tmux-resurrect/issues/438), [363](https://github.com/tmux-plugins/tmux-resurrect/issues/363) | window name starting with a number / 7th-index misplacement | window-index parse + quoting |
| [482](https://github.com/tmux-plugins/tmux-resurrect/issues/482), [254](https://github.com/tmux-plugins/tmux-resurrect/issues/254), [159](https://github.com/tmux-plugins/tmux-resurrect/issues/159) | wrong PWD when cwd is a symlink / `$HOME` link | option to keep logical path vs resolved |
| [277](https://github.com/tmux-plugins/tmux-resurrect/issues/277), [205](https://github.com/tmux-plugins/tmux-resurrect/issues/205), [439](https://github.com/tmux-plugins/tmux-resurrect/issues/439) | `$CWD` taken from the vim child, not the shell | use the pane shell cwd in `dump_panes` |
| [90](https://github.com/tmux-plugins/tmux-resurrect/issues/90), [364](https://github.com/tmux-plugins/tmux-resurrect/issues/364), [336](https://github.com/tmux-plugins/tmux-resurrect/issues/336), [477](https://github.com/tmux-plugins/tmux-resurrect/issues/477) | new windows inherit first window's path / wrong session cwd | set session working dir correctly on restore |
| [530](https://github.com/tmux-plugins/tmux-resurrect/issues/530) | neovim AppImage path under `/tmp` | process-path rewrite strategy |
| [517](https://github.com/tmux-plugins/tmux-resurrect/issues/517), [508](https://github.com/tmux-plugins/tmux-resurrect/issues/508) | `split-window <cmd>` / `echo;ssh` — child command lost | capture the full child command, not just the first proc |
| [470](https://github.com/tmux-plugins/tmux-resurrect/issues/470), [421](https://github.com/tmux-plugins/tmux-resurrect/issues/421), [274](https://github.com/tmux-plugins/tmux-resurrect/issues/274), [326](https://github.com/tmux-plugins/tmux-resurrect/issues/326), [119](https://github.com/tmux-plugins/tmux-resurrect/issues/119), [356](https://github.com/tmux-plugins/tmux-resurrect/issues/356) | vim/nvim session not restored / sizing / `^M` / insert-mode | `vim_session.sh` / `nvim_session.sh` + restore timing |
| [223](https://github.com/tmux-plugins/tmux-resurrect/issues/223) | vim in a split not sized (neovim) | `select-layout` after process spawn / refresh |
| [353](https://github.com/tmux-plugins/tmux-resurrect/issues/353), [391](https://github.com/tmux-plugins/tmux-resurrect/issues/391) | wrong binary path / match whole path not basename | basename-limited process matching |
| [403](https://github.com/tmux-plugins/tmux-resurrect/issues/403), [115](https://github.com/tmux-plugins/tmux-resurrect/issues/115) | corrupted / 0-length snapshot leaves a bad `last` | atomic save: validate staging before `snapshot_create` updates `last` |
| [189](https://github.com/tmux-plugins/tmux-resurrect/issues/189) | `#S` / window name stuck after restore | `automatic-rename` reapply |
| [309](https://github.com/tmux-plugins/tmux-resurrect/issues/309) | restore can clobber state with no confirm/snapshot | pre-restore safety snapshot |
| [132](https://github.com/tmux-plugins/tmux-resurrect/issues/132) | window options not restored (e.g. `monitor-activity`) | extend `dump_windows` / restore |
| [365](https://github.com/tmux-plugins/tmux-resurrect/issues/365), [207](https://github.com/tmux-plugins/tmux-resurrect/issues/207) | no per-socket (`-L`) separation | namespace snapshots by socket |
| [388](https://github.com/tmux-plugins/tmux-resurrect/issues/388) | session/window index vs name order on restore | ordering pass |
| [471](https://github.com/tmux-plugins/tmux-resurrect/issues/471) | unicode (Greek) window name breaks save deletion | filename / pruning safety for non-ASCII |
| [555](https://github.com/tmux-plugins/tmux-resurrect/issues/555) | CWD resets to `$HOME` on pane-contents restore (dup-prompt half already fixed) | dir handling in the `pane_creation_command` path |

### Hard — architectural / inherent to `ps`-capture / platform

| Issue(s) | Theme |
|---|---|
| [540](https://github.com/tmux-plugins/tmux-resurrect/issues/540), [292](https://github.com/tmux-plugins/tmux-resurrect/issues/292), [499](https://github.com/tmux-plugins/tmux-resurrect/issues/499), [162](https://github.com/tmux-plugins/tmux-resurrect/issues/162), [60](https://github.com/tmux-plugins/tmux-resurrect/issues/60), [154](https://github.com/tmux-plugins/tmux-resurrect/issues/154), [440](https://github.com/tmux-plugins/tmux-resurrect/issues/440) | quote/escape/alias loss — `ps` argv is unquoted; needs `/proc/pid/cmdline` capture + re-quoting |
| [338](https://github.com/tmux-plugins/tmux-resurrect/issues/338), [253](https://github.com/tmux-plugins/tmux-resurrect/issues/253), [158](https://github.com/tmux-plugins/tmux-resurrect/issues/158), [467](https://github.com/tmux-plugins/tmux-resurrect/issues/467), [418](https://github.com/tmux-plugins/tmux-resurrect/issues/418), [411](https://github.com/tmux-plugins/tmux-resurrect/issues/411), [108](https://github.com/tmux-plugins/tmux-resurrect/issues/108), [44](https://github.com/tmux-plugins/tmux-resurrect/issues/44) | PPID / process-name capture limits — external panes, suspended/bg, same-name-diff-cmd, nested launchers |
| [544](https://github.com/tmux-plugins/tmux-resurrect/issues/544), [379](https://github.com/tmux-plugins/tmux-resurrect/issues/379), [383](https://github.com/tmux-plugins/tmux-resurrect/issues/383) | `capture-pane` / `ps.sh` CPU + hang on huge history / macOS sleep |
| [535](https://github.com/tmux-plugins/tmux-resurrect/issues/535), [494](https://github.com/tmux-plugins/tmux-resurrect/issues/494) | restore needs an attached terminal (`switch-client`) — headless redesign |
| [437](https://github.com/tmux-plugins/tmux-resurrect/issues/437), [304](https://github.com/tmux-plugins/tmux-resurrect/issues/304), [269](https://github.com/tmux-plugins/tmux-resurrect/issues/269), [280](https://github.com/tmux-plugins/tmux-resurrect/issues/280), [195](https://github.com/tmux-plugins/tmux-resurrect/issues/195) | pane-placement corruption / partial restore / large-monitor sizing |
| [234](https://github.com/tmux-plugins/tmux-resurrect/issues/234), [134](https://github.com/tmux-plugins/tmux-resurrect/issues/134) | linked windows restored as separate windows |
| [332](https://github.com/tmux-plugins/tmux-resurrect/issues/332), [456](https://github.com/tmux-plugins/tmux-resurrect/issues/456) | `$DISPLAY` / `TERM` / env not restored |
| [473](https://github.com/tmux-plugins/tmux-resurrect/issues/473), [247](https://github.com/tmux-plugins/tmux-resurrect/issues/247), [131](https://github.com/tmux-plugins/tmux-resurrect/issues/131), [198](https://github.com/tmux-plugins/tmux-resurrect/issues/198), [123](https://github.com/tmux-plugins/tmux-resurrect/issues/123), [128](https://github.com/tmux-plugins/tmux-resurrect/issues/128), [293](https://github.com/tmux-plugins/tmux-resurrect/issues/293) | platform-specific (NixOS path churn, Cygwin `ps`/`pgrep`, Windows paths, sudo cwd) |
| [559](https://github.com/tmux-plugins/tmux-resurrect/issues/559) | `kill-server` SIGHUP skips shell exit handlers (workflow / by-design mitigation) |
| [290](https://github.com/tmux-plugins/tmux-resurrect/issues/290), [315](https://github.com/tmux-plugins/tmux-resurrect/issues/315) | non-login shells lose aliases/completion (intermittent; links to [497](https://github.com/tmux-plugins/tmux-resurrect/issues/497)) |
| [237](https://github.com/tmux-plugins/tmux-resurrect/issues/237) | a corrupt pane-contents tar aborts the whole restore — needs per-pane fault isolation |
| [374](https://github.com/tmux-plugins/tmux-resurrect/issues/374) | default apps reset after first resurrect (obscure; investigate before fixing) |

---

## Bucket C — Not a bug

### Feature requests (potential roadmap, not defects)

| Issue | Summary |
|---|---|
| [552](https://github.com/tmux-plugins/tmux-resurrect/issues/552) | Save, delete, and restore individual sessions |
| [542](https://github.com/tmux-plugins/tmux-resurrect/issues/542) | Keep state files in `$XDG_STATE_HOME`, not `$XDG_DATA_HOME` |
| [539](https://github.com/tmux-plugins/tmux-resurrect/issues/539) | Restore without attaching / control which session attaches |
| [516](https://github.com/tmux-plugins/tmux-resurrect/issues/516) | Restore the open file in the `nnn` file manager |
| [515](https://github.com/tmux-plugins/tmux-resurrect/issues/515) | Bind save/restore to a non-prefix client key table (`-T`) |
| [498](https://github.com/tmux-plugins/tmux-resurrect/issues/498) | Create sessions/windows/layouts from a declarative file |
| [484](https://github.com/tmux-plugins/tmux-resurrect/issues/484) | Save & restore window/session env variables |
| [479](https://github.com/tmux-plugins/tmux-resurrect/issues/479) | Resurrect only named sessions |
| [466](https://github.com/tmux-plugins/tmux-resurrect/issues/466) | Remove/unsave a session from the resurrect list |
| [433](https://github.com/tmux-plugins/tmux-resurrect/issues/433) | Restore a program piped into another (e.g. `\| grep`) |
| [428](https://github.com/tmux-plugins/tmux-resurrect/issues/428) | Linux CRIU checkpoint/restore of live processes |
| [424](https://github.com/tmux-plugins/tmux-resurrect/issues/424) | Save to / load from a user-specified file |
| [417](https://github.com/tmux-plugins/tmux-resurrect/issues/417) | Save & restore the bash directory stack (`pushd`/`popd`) |
| [410](https://github.com/tmux-plugins/tmux-resurrect/issues/410) | Log resurrect actions to ease troubleshooting |
| [407](https://github.com/tmux-plugins/tmux-resurrect/issues/407) | Restore only the active pane of a window |
| [402](https://github.com/tmux-plugins/tmux-resurrect/issues/402) | Restore a docker-container launch command |
| [385](https://github.com/tmux-plugins/tmux-resurrect/issues/385) | Explicitly remove/unsave a session before killing it |
| [382](https://github.com/tmux-plugins/tmux-resurrect/issues/382) | Match restorable processes by prefix/regex |
| [380](https://github.com/tmux-plugins/tmux-resurrect/issues/380) | Safe mode: store commands but don't auto-run them |
| [368](https://github.com/tmux-plugins/tmux-resurrect/issues/368) | Let `bashrc` detect a resurrect-started shell |
| [357](https://github.com/tmux-plugins/tmux-resurrect/issues/357) | Wildcard restore of commands / restore a single window |
| [351](https://github.com/tmux-plugins/tmux-resurrect/issues/351) | Remember per-pane colors |
| [312](https://github.com/tmux-plugins/tmux-resurrect/issues/312) | Save arbitrary pane metadata (env vars) — external plugin |
| [306](https://github.com/tmux-plugins/tmux-resurrect/issues/306) | Length limit for pane-contents capture on huge history |
| [299](https://github.com/tmux-plugins/tmux-resurrect/issues/299) | In-terminal apps (e.g. `mutt`) restoring — process config |
| [264](https://github.com/tmux-plugins/tmux-resurrect/issues/264) | `@resurrect-processes` ssh restore — config |
| [249](https://github.com/tmux-plugins/tmux-resurrect/issues/249) | Save NERDTree (vim plugin) state |
| [246](https://github.com/tmux-plugins/tmux-resurrect/issues/246) | Set `resurrect-dir` dynamically per project |
| [241](https://github.com/tmux-plugins/tmux-resurrect/issues/241) | Disable loading vim by default — config |
| [240](https://github.com/tmux-plugins/tmux-resurrect/issues/240) | Restore a python virtualenv |
| [235](https://github.com/tmux-plugins/tmux-resurrect/issues/235) | Env var so programs can detect they're being resurrected |
| [213](https://github.com/tmux-plugins/tmux-resurrect/issues/213) | Run a command after a session is resurrected |
| [208](https://github.com/tmux-plugins/tmux-resurrect/issues/208) | Restore `tmux clock-mode` in a dedicated pane |
| [199](https://github.com/tmux-plugins/tmux-resurrect/issues/199) | tmuxinator-style run-command-per-pane |
| [190](https://github.com/tmux-plugins/tmux-resurrect/issues/190) | Use `$HOME` for portable paths across machines |
| [187](https://github.com/tmux-plugins/tmux-resurrect/issues/187) | Enter a VM (`lxc-attach`/`pct enter`) on restore |
| [178](https://github.com/tmux-plugins/tmux-resurrect/issues/178) | One tmux instance per GNU screen window (multi-server) |
| [171](https://github.com/tmux-plugins/tmux-resurrect/issues/171) | Restore a remote vim session over ssh |
| [166](https://github.com/tmux-plugins/tmux-resurrect/issues/166) | Save the directory-change history list |
| [106](https://github.com/tmux-plugins/tmux-resurrect/issues/106) | Add file managers to the default program list |
| [81](https://github.com/tmux-plugins/tmux-resurrect/issues/81) | Tracking issue: improving the pane-contents feature |

### Questions / support / config / user-error

| Issue | Summary |
|---|---|
| [532](https://github.com/tmux-plugins/tmux-resurrect/issues/532) | How to save `emacsclient` + magit |
| [514](https://github.com/tmux-plugins/tmux-resurrect/issues/514) | "Breaks config" — actually a quote typo in the user's `@plugin` line |
| [512](https://github.com/tmux-plugins/tmux-resurrect/issues/512) | Save/restore returns 127 — install/path |
| [501](https://github.com/tmux-plugins/tmux-resurrect/issues/501) | How to upgrade 3.0 → 4.0 keeping saved sessions |
| [491](https://github.com/tmux-plugins/tmux-resurrect/issues/491) | How to start the tmux server with restore |
| [490](https://github.com/tmux-plugins/tmux-resurrect/issues/490) | "unknown command: pane" — sourced the resurrect file as config |
| [478](https://github.com/tmux-plugins/tmux-resurrect/issues/478) | Save file not created — continuum/config |
| [472](https://github.com/tmux-plugins/tmux-resurrect/issues/472) | Difference between resurrect and continuum |
| [444](https://github.com/tmux-plugins/tmux-resurrect/issues/444) | Restoring ssh sessions not working — config |
| [441](https://github.com/tmux-plugins/tmux-resurrect/issues/441) | Ubuntu 22 / tmux 3.2 does not save |
| [413](https://github.com/tmux-plugins/tmux-resurrect/issues/413) | Stopped restoring programs suddenly — config/env |
| [386](https://github.com/tmux-plugins/tmux-resurrect/issues/386) | tmux 3.1c prefix Ctrl-r fails — config |
| [378](https://github.com/tmux-plugins/tmux-resurrect/issues/378) | Source nvim session from a different directory |
| [377](https://github.com/tmux-plugins/tmux-resurrect/issues/377) | `resurrect.tmux` returned 126 — exec bit/path |
| [375](https://github.com/tmux-plugins/tmux-resurrect/issues/375) | `resurrect.tmux` returned 1 on load — install |
| [371](https://github.com/tmux-plugins/tmux-resurrect/issues/371) | "Requires no configuration" — how does restore happen? |
| [346](https://github.com/tmux-plugins/tmux-resurrect/issues/346) | Saved sessions gone after reboot — `/tmp` socket cleared |
| [344](https://github.com/tmux-plugins/tmux-resurrect/issues/344) | How do I know if it saved? |
| [341](https://github.com/tmux-plugins/tmux-resurrect/issues/341) | How to clear saved sessions |
| [337](https://github.com/tmux-plugins/tmux-resurrect/issues/337) | node command not restored — process config |
| [333](https://github.com/tmux-plugins/tmux-resurrect/issues/333) | Share resurrect files across computers (WSL) |
| [311](https://github.com/tmux-plugins/tmux-resurrect/issues/311) | Can't restore after `kill-session` — gpakosz config |
| [259](https://github.com/tmux-plugins/tmux-resurrect/issues/259) | How to enable quiet-mode save |
| [245](https://github.com/tmux-plugins/tmux-resurrect/issues/245) | Save/reload stopped working after detach |
| [203](https://github.com/tmux-plugins/tmux-resurrect/issues/203) | TPM does not install the plugin |
| [196](https://github.com/tmux-plugins/tmux-resurrect/issues/196) | Automatic restore stopped on tmux 2.5 — old version |
| [173](https://github.com/tmux-plugins/tmux-resurrect/issues/173) | Does it work with nested sessions? |
| [160](https://github.com/tmux-plugins/tmux-resurrect/issues/160) | Newbie: multiple projects + vim sessions |
| [147](https://github.com/tmux-plugins/tmux-resurrect/issues/147) | How to restore Empire PowerShell |
| [138](https://github.com/tmux-plugins/tmux-resurrect/issues/138) | Manually create `last.txt` content |
| [129](https://github.com/tmux-plugins/tmux-resurrect/issues/129) | Restore not starting processes — config |
| [121](https://github.com/tmux-plugins/tmux-resurrect/issues/121) | Does it need zsh as the default shell? |
| [120](https://github.com/tmux-plugins/tmux-resurrect/issues/120) | Best way to close a complex session after saving |
| [99](https://github.com/tmux-plugins/tmux-resurrect/issues/99) | How to restore from an earlier backup |

### Docs / meta

| Issue | Summary |
|---|---|
| [565](https://github.com/tmux-plugins/tmux-resurrect/issues/565) | Rate the demo Vimeo video so it needs no account |
| [545](https://github.com/tmux-plugins/tmux-resurrect/issues/545) | Mention `$XDG_DATA_HOME` save location in docs |
| [519](https://github.com/tmux-plugins/tmux-resurrect/issues/519) | Is bash-history saving supported? — docs (feature removed) |
| [489](https://github.com/tmux-plugins/tmux-resurrect/issues/489) | `save_dir.md` is incomplete (XDG path) |
| [460](https://github.com/tmux-plugins/tmux-resurrect/issues/460) | Update docs for the XDG dir |
| [412](https://github.com/tmux-plugins/tmux-resurrect/issues/412) | `save_dir.md` quoting error (single vs double quotes) |
| [349](https://github.com/tmux-plugins/tmux-resurrect/issues/349) | Update README screencast to the new key bindings |
| [317](https://github.com/tmux-plugins/tmux-resurrect/issues/317) | Faulty info in `restoring_pane_contents.md` |
| [265](https://github.com/tmux-plugins/tmux-resurrect/issues/265) | User-posted workaround for "does not restore" |
| [221](https://github.com/tmux-plugins/tmux-resurrect/issues/221) | No CONTRIBUTING docs for running the tests |

### By-design limitations

| Issue | Summary |
|---|---|
| [355](https://github.com/tmux-plugins/tmux-resurrect/issues/355) | sshfs-mounted folders unavailable at restore time |
| [301](https://github.com/tmux-plugins/tmux-resurrect/issues/301) | git prompt broken — restored pane contents are static text |
| [179](https://github.com/tmux-plugins/tmux-resurrect/issues/179) | `tmux -CC` (iTerm) has no prefix key table |
</content>
