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
  classified **Easy / Medium / Hard**. Tracked as issues in the
  [Tmux Resurrect Upstream Issues](https://github.com/users/hyoretsu/projects/9)
  project — see the [mapping table](#upstream--fork-issue-mapping) below.
- **C — Not a bug:** questions, feature requests, docs, or by-design limits.
  Feature requests are tracked in the same project.

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

## Bucket C — Not a bug

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

---

## Upstream → fork issue mapping

Bucket B bugs and C feature requests are tracked in the
[Tmux Resurrect Upstream Issues](https://github.com/users/hyoretsu/projects/9)
project. Multiple upstream issues sharing a theme are grouped under a single
fork issue.

| Upstream (tmux-resurrect) | Fork (tmux-persist) |
|---|---|
| [44](https://github.com/tmux-plugins/tmux-resurrect/issues/44) | [#29](https://github.com/hyoretsu/tmux-persist/issues/29) |
| [60](https://github.com/tmux-plugins/tmux-resurrect/issues/60) | [#28](https://github.com/hyoretsu/tmux-persist/issues/28) |
| [65](https://github.com/tmux-plugins/tmux-resurrect/issues/65) | [#10](https://github.com/hyoretsu/tmux-persist/issues/10) |
| [81](https://github.com/tmux-plugins/tmux-resurrect/issues/81) | [#80](https://github.com/hyoretsu/tmux-persist/issues/80) |
| [90](https://github.com/tmux-plugins/tmux-resurrect/issues/90) | [#14](https://github.com/hyoretsu/tmux-persist/issues/14) |
| [106](https://github.com/tmux-plugins/tmux-resurrect/issues/106) | [#79](https://github.com/hyoretsu/tmux-persist/issues/79) |
| [108](https://github.com/tmux-plugins/tmux-resurrect/issues/108) | [#29](https://github.com/hyoretsu/tmux-persist/issues/29) |
| [115](https://github.com/tmux-plugins/tmux-resurrect/issues/115) | [#20](https://github.com/hyoretsu/tmux-persist/issues/20) |
| [119](https://github.com/tmux-plugins/tmux-resurrect/issues/119) | [#17](https://github.com/hyoretsu/tmux-persist/issues/17) |
| [123](https://github.com/tmux-plugins/tmux-resurrect/issues/123) | [#36](https://github.com/hyoretsu/tmux-persist/issues/36) |
| [128](https://github.com/tmux-plugins/tmux-resurrect/issues/128) | [#36](https://github.com/hyoretsu/tmux-persist/issues/36) |
| [131](https://github.com/tmux-plugins/tmux-resurrect/issues/131) | [#36](https://github.com/hyoretsu/tmux-persist/issues/36) |
| [132](https://github.com/tmux-plugins/tmux-resurrect/issues/132) | [#23](https://github.com/hyoretsu/tmux-persist/issues/23) |
| [134](https://github.com/tmux-plugins/tmux-resurrect/issues/134) | [#33](https://github.com/hyoretsu/tmux-persist/issues/33) |
| [154](https://github.com/tmux-plugins/tmux-resurrect/issues/154) | [#28](https://github.com/hyoretsu/tmux-persist/issues/28) |
| [158](https://github.com/tmux-plugins/tmux-resurrect/issues/158) | [#29](https://github.com/hyoretsu/tmux-persist/issues/29) |
| [159](https://github.com/tmux-plugins/tmux-resurrect/issues/159) | [#12](https://github.com/hyoretsu/tmux-persist/issues/12) |
| [162](https://github.com/tmux-plugins/tmux-resurrect/issues/162) | [#28](https://github.com/hyoretsu/tmux-persist/issues/28) |
| [166](https://github.com/tmux-plugins/tmux-resurrect/issues/166) | [#78](https://github.com/hyoretsu/tmux-persist/issues/78) |
| [171](https://github.com/tmux-plugins/tmux-resurrect/issues/171) | [#77](https://github.com/hyoretsu/tmux-persist/issues/77) |
| [178](https://github.com/tmux-plugins/tmux-resurrect/issues/178) | [#76](https://github.com/hyoretsu/tmux-persist/issues/76) |
| [187](https://github.com/tmux-plugins/tmux-resurrect/issues/187) | [#75](https://github.com/hyoretsu/tmux-persist/issues/75) |
| [189](https://github.com/tmux-plugins/tmux-resurrect/issues/189) | [#21](https://github.com/hyoretsu/tmux-persist/issues/21) |
| [190](https://github.com/tmux-plugins/tmux-resurrect/issues/190) | [#74](https://github.com/hyoretsu/tmux-persist/issues/74) |
| [195](https://github.com/tmux-plugins/tmux-resurrect/issues/195) | [#32](https://github.com/hyoretsu/tmux-persist/issues/32) |
| [198](https://github.com/tmux-plugins/tmux-resurrect/issues/198) | [#36](https://github.com/hyoretsu/tmux-persist/issues/36) |
| [199](https://github.com/tmux-plugins/tmux-resurrect/issues/199) | [#73](https://github.com/hyoretsu/tmux-persist/issues/73) |
| [205](https://github.com/tmux-plugins/tmux-resurrect/issues/205) | [#13](https://github.com/hyoretsu/tmux-persist/issues/13) |
| [207](https://github.com/tmux-plugins/tmux-resurrect/issues/207) | [#24](https://github.com/hyoretsu/tmux-persist/issues/24) |
| [208](https://github.com/tmux-plugins/tmux-resurrect/issues/208) | [#72](https://github.com/hyoretsu/tmux-persist/issues/72) |
| [213](https://github.com/tmux-plugins/tmux-resurrect/issues/213) | [#71](https://github.com/hyoretsu/tmux-persist/issues/71) |
| [223](https://github.com/tmux-plugins/tmux-resurrect/issues/223) | [#18](https://github.com/hyoretsu/tmux-persist/issues/18) |
| [234](https://github.com/tmux-plugins/tmux-resurrect/issues/234) | [#33](https://github.com/hyoretsu/tmux-persist/issues/33) |
| [235](https://github.com/tmux-plugins/tmux-resurrect/issues/235) | [#70](https://github.com/hyoretsu/tmux-persist/issues/70) |
| [237](https://github.com/tmux-plugins/tmux-resurrect/issues/237) | [#39](https://github.com/hyoretsu/tmux-persist/issues/39) |
| [240](https://github.com/tmux-plugins/tmux-resurrect/issues/240) | [#69](https://github.com/hyoretsu/tmux-persist/issues/69) |
| [241](https://github.com/tmux-plugins/tmux-resurrect/issues/241) | [#68](https://github.com/hyoretsu/tmux-persist/issues/68) |
| [246](https://github.com/tmux-plugins/tmux-resurrect/issues/246) | [#67](https://github.com/hyoretsu/tmux-persist/issues/67) |
| [247](https://github.com/tmux-plugins/tmux-resurrect/issues/247) | [#36](https://github.com/hyoretsu/tmux-persist/issues/36) |
| [249](https://github.com/tmux-plugins/tmux-resurrect/issues/249) | [#66](https://github.com/hyoretsu/tmux-persist/issues/66) |
| [253](https://github.com/tmux-plugins/tmux-resurrect/issues/253) | [#29](https://github.com/hyoretsu/tmux-persist/issues/29) |
| [254](https://github.com/tmux-plugins/tmux-resurrect/issues/254) | [#12](https://github.com/hyoretsu/tmux-persist/issues/12) |
| [264](https://github.com/tmux-plugins/tmux-resurrect/issues/264) | [#65](https://github.com/hyoretsu/tmux-persist/issues/65) |
| [269](https://github.com/tmux-plugins/tmux-resurrect/issues/269) | [#32](https://github.com/hyoretsu/tmux-persist/issues/32) |
| [274](https://github.com/tmux-plugins/tmux-resurrect/issues/274) | [#17](https://github.com/hyoretsu/tmux-persist/issues/17) |
| [277](https://github.com/tmux-plugins/tmux-resurrect/issues/277) | [#13](https://github.com/hyoretsu/tmux-persist/issues/13) |
| [280](https://github.com/tmux-plugins/tmux-resurrect/issues/280) | [#32](https://github.com/hyoretsu/tmux-persist/issues/32) |
| [290](https://github.com/tmux-plugins/tmux-resurrect/issues/290) | [#38](https://github.com/hyoretsu/tmux-persist/issues/38) |
| [292](https://github.com/tmux-plugins/tmux-resurrect/issues/292) | [#28](https://github.com/hyoretsu/tmux-persist/issues/28) |
| [293](https://github.com/tmux-plugins/tmux-resurrect/issues/293) | [#36](https://github.com/hyoretsu/tmux-persist/issues/36) |
| [299](https://github.com/tmux-plugins/tmux-resurrect/issues/299) | [#64](https://github.com/hyoretsu/tmux-persist/issues/64) |
| [304](https://github.com/tmux-plugins/tmux-resurrect/issues/304) | [#32](https://github.com/hyoretsu/tmux-persist/issues/32) |
| [306](https://github.com/tmux-plugins/tmux-resurrect/issues/306) | [#63](https://github.com/hyoretsu/tmux-persist/issues/63) |
| [309](https://github.com/tmux-plugins/tmux-resurrect/issues/309) | [#22](https://github.com/hyoretsu/tmux-persist/issues/22) |
| [312](https://github.com/tmux-plugins/tmux-resurrect/issues/312) | [#34](https://github.com/hyoretsu/tmux-persist/issues/34) |
| [315](https://github.com/tmux-plugins/tmux-resurrect/issues/315) | [#38](https://github.com/hyoretsu/tmux-persist/issues/38) |
| [323](https://github.com/tmux-plugins/tmux-resurrect/issues/323) | [#7](https://github.com/hyoretsu/tmux-persist/issues/7) |
| [326](https://github.com/tmux-plugins/tmux-resurrect/issues/326) | [#17](https://github.com/hyoretsu/tmux-persist/issues/17) |
| [332](https://github.com/tmux-plugins/tmux-resurrect/issues/332) | [#34](https://github.com/hyoretsu/tmux-persist/issues/34) |
| [336](https://github.com/tmux-plugins/tmux-resurrect/issues/336) | [#14](https://github.com/hyoretsu/tmux-persist/issues/14) |
| [338](https://github.com/tmux-plugins/tmux-resurrect/issues/338) | [#29](https://github.com/hyoretsu/tmux-persist/issues/29) |
| [351](https://github.com/tmux-plugins/tmux-resurrect/issues/351) | [#62](https://github.com/hyoretsu/tmux-persist/issues/62) |
| [353](https://github.com/tmux-plugins/tmux-resurrect/issues/353) | [#19](https://github.com/hyoretsu/tmux-persist/issues/19) |
| [356](https://github.com/tmux-plugins/tmux-resurrect/issues/356) | [#17](https://github.com/hyoretsu/tmux-persist/issues/17) |
| [357](https://github.com/tmux-plugins/tmux-resurrect/issues/357) | [#61](https://github.com/hyoretsu/tmux-persist/issues/61) |
| [363](https://github.com/tmux-plugins/tmux-resurrect/issues/363) | [#11](https://github.com/hyoretsu/tmux-persist/issues/11) |
| [364](https://github.com/tmux-plugins/tmux-resurrect/issues/364) | [#14](https://github.com/hyoretsu/tmux-persist/issues/14) |
| [365](https://github.com/tmux-plugins/tmux-resurrect/issues/365) | [#24](https://github.com/hyoretsu/tmux-persist/issues/24) |
| [368](https://github.com/tmux-plugins/tmux-resurrect/issues/368) | [#60](https://github.com/hyoretsu/tmux-persist/issues/60) |
| [374](https://github.com/tmux-plugins/tmux-resurrect/issues/374) | [#40](https://github.com/hyoretsu/tmux-persist/issues/40) |
| [379](https://github.com/tmux-plugins/tmux-resurrect/issues/379) | [#30](https://github.com/hyoretsu/tmux-persist/issues/30) |
| [380](https://github.com/tmux-plugins/tmux-resurrect/issues/380) | [#59](https://github.com/hyoretsu/tmux-persist/issues/59) |
| [382](https://github.com/tmux-plugins/tmux-resurrect/issues/382) | [#58](https://github.com/hyoretsu/tmux-persist/issues/58) |
| [383](https://github.com/tmux-plugins/tmux-resurrect/issues/383) | [#30](https://github.com/hyoretsu/tmux-persist/issues/30) |
| [385](https://github.com/tmux-plugins/tmux-resurrect/issues/385) | [#57](https://github.com/hyoretsu/tmux-persist/issues/57) |
| [388](https://github.com/tmux-plugins/tmux-resurrect/issues/388) | [#25](https://github.com/hyoretsu/tmux-persist/issues/25) |
| [391](https://github.com/tmux-plugins/tmux-resurrect/issues/391) | [#19](https://github.com/hyoretsu/tmux-persist/issues/19) |
| [402](https://github.com/tmux-plugins/tmux-resurrect/issues/402) | [#56](https://github.com/hyoretsu/tmux-persist/issues/56) |
| [403](https://github.com/tmux-plugins/tmux-resurrect/issues/403) | [#20](https://github.com/hyoretsu/tmux-persist/issues/20) |
| [407](https://github.com/tmux-plugins/tmux-resurrect/issues/407) | [#55](https://github.com/hyoretsu/tmux-persist/issues/55) |
| [410](https://github.com/tmux-plugins/tmux-resurrect/issues/410) | [#54](https://github.com/hyoretsu/tmux-persist/issues/54) |
| [411](https://github.com/tmux-plugins/tmux-resurrect/issues/411) | [#29](https://github.com/hyoretsu/tmux-persist/issues/29) |
| [415](https://github.com/tmux-plugins/tmux-resurrect/issues/415) | [#6](https://github.com/hyoretsu/tmux-persist/issues/6) |
| [417](https://github.com/tmux-plugins/tmux-resurrect/issues/417) | [#53](https://github.com/hyoretsu/tmux-persist/issues/53) |
| [418](https://github.com/tmux-plugins/tmux-resurrect/issues/418) | [#29](https://github.com/hyoretsu/tmux-persist/issues/29) |
| [421](https://github.com/tmux-plugins/tmux-resurrect/issues/421) | [#17](https://github.com/hyoretsu/tmux-persist/issues/17) |
| [424](https://github.com/tmux-plugins/tmux-resurrect/issues/424) | [#52](https://github.com/hyoretsu/tmux-persist/issues/52) |
| [428](https://github.com/tmux-plugins/tmux-resurrect/issues/428) | [#51](https://github.com/hyoretsu/tmux-persist/issues/51) |
| [433](https://github.com/tmux-plugins/tmux-resurrect/issues/433) | [#50](https://github.com/hyoretsu/tmux-persist/issues/50) |
| [437](https://github.com/tmux-plugins/tmux-resurrect/issues/437) | [#32](https://github.com/hyoretsu/tmux-persist/issues/32) |
| [438](https://github.com/tmux-plugins/tmux-resurrect/issues/438) | [#11](https://github.com/hyoretsu/tmux-persist/issues/11) |
| [439](https://github.com/tmux-plugins/tmux-resurrect/issues/439) | [#13](https://github.com/hyoretsu/tmux-persist/issues/13) |
| [440](https://github.com/tmux-plugins/tmux-resurrect/issues/440) | [#28](https://github.com/hyoretsu/tmux-persist/issues/28) |
| [456](https://github.com/tmux-plugins/tmux-resurrect/issues/456) | [#34](https://github.com/hyoretsu/tmux-persist/issues/34) |
| [466](https://github.com/tmux-plugins/tmux-resurrect/issues/466) | [#49](https://github.com/hyoretsu/tmux-persist/issues/49) |
| [467](https://github.com/tmux-plugins/tmux-resurrect/issues/467) | [#29](https://github.com/hyoretsu/tmux-persist/issues/29) |
| [470](https://github.com/tmux-plugins/tmux-resurrect/issues/470) | [#17](https://github.com/hyoretsu/tmux-persist/issues/17) |
| [471](https://github.com/tmux-plugins/tmux-resurrect/issues/471) | [#26](https://github.com/hyoretsu/tmux-persist/issues/26) |
| [473](https://github.com/tmux-plugins/tmux-resurrect/issues/473) | [#36](https://github.com/hyoretsu/tmux-persist/issues/36) |
| [477](https://github.com/tmux-plugins/tmux-resurrect/issues/477) | [#14](https://github.com/hyoretsu/tmux-persist/issues/14) |
| [479](https://github.com/tmux-plugins/tmux-resurrect/issues/479) | [#48](https://github.com/hyoretsu/tmux-persist/issues/48) |
| [482](https://github.com/tmux-plugins/tmux-resurrect/issues/482) | [#12](https://github.com/hyoretsu/tmux-persist/issues/12) |
| [484](https://github.com/tmux-plugins/tmux-resurrect/issues/484) | [#47](https://github.com/hyoretsu/tmux-persist/issues/47) |
| [485](https://github.com/tmux-plugins/tmux-resurrect/issues/485) | [#8](https://github.com/hyoretsu/tmux-persist/issues/8) |
| [492](https://github.com/tmux-plugins/tmux-resurrect/issues/492) | [#10](https://github.com/hyoretsu/tmux-persist/issues/10) |
| [494](https://github.com/tmux-plugins/tmux-resurrect/issues/494) | [#31](https://github.com/hyoretsu/tmux-persist/issues/31) |
| [497](https://github.com/tmux-plugins/tmux-resurrect/issues/497) | [#4](https://github.com/hyoretsu/tmux-persist/issues/4) |
| [498](https://github.com/tmux-plugins/tmux-resurrect/issues/498) | [#46](https://github.com/hyoretsu/tmux-persist/issues/46) |
| [499](https://github.com/tmux-plugins/tmux-resurrect/issues/499) | [#28](https://github.com/hyoretsu/tmux-persist/issues/28) |
| [508](https://github.com/tmux-plugins/tmux-resurrect/issues/508) | [#16](https://github.com/hyoretsu/tmux-persist/issues/16) |
| [515](https://github.com/tmux-plugins/tmux-resurrect/issues/515) | [#45](https://github.com/hyoretsu/tmux-persist/issues/45) |
| [516](https://github.com/tmux-plugins/tmux-resurrect/issues/516) | [#44](https://github.com/hyoretsu/tmux-persist/issues/44) |
| [517](https://github.com/tmux-plugins/tmux-resurrect/issues/517) | [#16](https://github.com/hyoretsu/tmux-persist/issues/16) |
| [530](https://github.com/tmux-plugins/tmux-resurrect/issues/530) | [#15](https://github.com/hyoretsu/tmux-persist/issues/15) |
| [535](https://github.com/tmux-plugins/tmux-resurrect/issues/535) | [#31](https://github.com/hyoretsu/tmux-persist/issues/31) |
| [539](https://github.com/tmux-plugins/tmux-resurrect/issues/539) | [#43](https://github.com/hyoretsu/tmux-persist/issues/43) |
| [540](https://github.com/tmux-plugins/tmux-resurrect/issues/540) | [#28](https://github.com/hyoretsu/tmux-persist/issues/28) |
| [542](https://github.com/tmux-plugins/tmux-resurrect/issues/542) | [#42](https://github.com/hyoretsu/tmux-persist/issues/42) |
| [543](https://github.com/tmux-plugins/tmux-resurrect/issues/543) | [#9](https://github.com/hyoretsu/tmux-persist/issues/9) |
| [544](https://github.com/tmux-plugins/tmux-resurrect/issues/544) | [#30](https://github.com/hyoretsu/tmux-persist/issues/30) |
| [548](https://github.com/tmux-plugins/tmux-resurrect/issues/548) | [#5](https://github.com/hyoretsu/tmux-persist/issues/5) |
| [552](https://github.com/tmux-plugins/tmux-resurrect/issues/552) | [#41](https://github.com/hyoretsu/tmux-persist/issues/41) |
| [555](https://github.com/tmux-plugins/tmux-resurrect/issues/555) | [#27](https://github.com/hyoretsu/tmux-persist/issues/27) |
| [559](https://github.com/tmux-plugins/tmux-resurrect/issues/559) | [#37](https://github.com/hyoretsu/tmux-persist/issues/37) |
| [561](https://github.com/tmux-plugins/tmux-resurrect/issues/561) | [#3](https://github.com/hyoretsu/tmux-persist/issues/3) |
| [563](https://github.com/tmux-plugins/tmux-resurrect/issues/563) | [#10](https://github.com/hyoretsu/tmux-persist/issues/10) |
</content>
