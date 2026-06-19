> The sections below apply across every project that uses this `AGENTS.md` / `CLAUDE.md`. The single project-specific block is **Business Rules — Source of Truth**, which is local to this repo.

## NEVER affect anything outside the local machine (absolute rule)

Never perform any action whose effect leaves this computer. No exceptions, ever, without an explicit per-instance request from the user.

Forbidden unless the user explicitly asks for that specific action:
- `git push` (or any push to a remote), creating/updating PRs, pushing tags.
- Running database migrations, schema pushes, seeds, or any command against a remote/shared/external database.
- Triggering CI/CD, deploys, or remote jobs; publishing packages; sending requests that mutate external services.

Local work is fine: edit files, run local builds/tests, commit locally. Stop at the local boundary and let the user push / migrate / deploy themselves. If a task seems to need crossing that boundary, describe the exact command and ask first.

## Business Rules — Source of Truth (project-specific)

Domain rules of the product (challenge lifecycle, betting limits, drawdown, breaches, antifraud, profit sharing, admin configuration, suggested entities) live in [`docs/business-rules/`](docs/business-rules/).

- Start at [`docs/business-rules/README.md`](docs/business-rules/README.md) for the index and LLM usage guide.
- For broad tasks (domain modeling, requirements, epic planning), feed the complete [`regras-completas.md`](docs/business-rules/regras-completas.md).
- For focused tasks, feed only the topical file relevant to the change (e.g. `03-betting-and-balance.md`, `05-penalties.md`).
- Always honor the prompt rules in [`prompt-llm.md`](docs/business-rules/prompt-llm.md): do not invent rules, surface open points instead of guessing, keep objective rules (block) separate from behavioral rules (penalize).

## Git Commits — Required After Every Completed Task

After finishing any task (feature, fix, refactor, or guideline addition), always create a git commit with **the agent that did the work** as the author and the local user as the committer:

```
git -c commit.gpgsign=false -c user.name="Aran Leite" -c user.email="hyoretsu@gmail.com" commit --author="<Agent> <agent-email>"
```

Each agent authors under its **own** identity — never under another agent's or any other third-party identity. The committer is always `Aran Leite <hyoretsu@gmail.com>`. Examples:

- Claude → `--author="Claude <noreply@anthropic.com>"`
- Codex → `--author="Codex <noreply@openai.com>"`

If the user requests an adjustment to something just delivered, amend or rebase rather than creating a separate noisy commit — keep history clean. Use Conventional Commits (`feat`, `fix`, `refactor`, `docs`, `style`, `chore`) with the monorepo package as scope (e.g. `feat(frontend)`, `fix(backend)`).

## Pre-PR / Pre-Merge Checks — Required Before Staging or Main

Before opening a PR or merging to `staging` or `main`, run a **type-check** and a **build check** — scoped to the **affected packages only** (don't rebuild the whole monorepo when one package changed). Both must pass before the merge/PR proceeds.

- Type-check: `bun run check-types` (Turbo runs each package's `check-types` = `tsc --noEmit`).
- Build: `bun run build` (Turbo's graph only rebuilds affected packages); scope with `turbo run build -F  when useful.

Enforced automatically in two places, so this is normally hands-off:
- **lefthook `pre-push`** runs `turbo check-types` + `turbo test:unit` locally.
- **CI** (single [`.github/workflows/ci.yml`](.github/workflows/ci.yml)): one `detect` job runs [`scripts/affected-packages.ts`](scripts/affected-packages.ts) **once** and emits a JSON object keyed by task. It asks Turbo's dependency graph (`turbo run <task> --affected`, base = PR base commit) for the packages that (a) are affected by the diff (changed **or** transitively depend on a changed package) and (b) define that task as a script. So a change to a shared lib also schedules the downstream package's job. Each downstream job (`check-types`, `build`, `unit`, `e2e`, `migrate`) is a **matrix over its own key**, so an unaffected package spawns no job (and shows nothing in the PR checks); an empty list skips the check. Per-check steps are extracted into composite actions under [`.github/actions/`](.github/actions/) (one per check + `detect-affected`), so `ci.yml` stays thin. `e2e` and `migrate` additionally gate on PRs targeting `staging`/`main`.

This is a local gate; running it never implies pushing or triggering CI — see the absolute local-boundary rule above.

## Serena — Required When Starting a Session

This project uses Serena. The full protocol is in `SERENA.md`/`@SERENA.md`.

**When starting any session, run these steps in order:**

1. Call `mcp__serena__initial_instructions` to read the Serena manual.
2. Call `mcp__serena__check_onboarding_performed`. If onboarding has not been performed, call `mcp__serena__onboarding`.
3. Before any work on code files, make Serena tools available. If Serena tools are not already visible in the active tool list, load them through `ToolSearch` first. Tool names may or may not have the `mcp__serena__` prefix depending on the agent/runtime.

Serena is PRIMARY for all TypeScript/TSX code. Built-in Read/Edit/Grep are SECONDARY — only use them when Serena fails or the target is not code.

## Caveman

Terse like caveman. Technical substance exact. Only fluff die.
Drop: articles, filler (just/really/basically), pleasantries, hedging.
Fragments OK. Short synonyms. Code unchanged.
Pattern: [thing] [action] [reason]. [next step].
ACTIVE EVERY RESPONSE. No revert after many turns. No filler drift.
Code/commits/PRs: normal. Off: "stop caveman" / "normal mode".

- Never put multiple components in the same file unless the file is intentionally using the Composition pattern. When a parent component needs private child components, turn it into a folder with `index.tsx`, move each child component to its own file, and place shared local types in `types.ts`.
- Always add ShadCN components through the ShadCN CLI.

## TanStack Router — Route File Convention

**Always use folder/index structure — never dot notation for multi-segment paths.**

```
✅ sports/$sportKey/events/$eventId.tsx
❌ sports.$sportKey.events.$eventId.tsx
```

- Nested route → create a folder, put page in `index.tsx` or a named file inside
- Layout-only files that just render `<Outlet />` can be omitted entirely — TanStack Router infers hierarchy from file names
- When moving files deeper, update all relative imports (depth increases, so `./components` → `../../components` etc.)
- After any route file change, rebuild so `routeTree.gen.ts` regenerates

## TanStack Router — File-Based Route Nesting

**A route file is a layout if it has child routes; it must render `<Outlet />`.** When a page (`foo.$param.tsx`) gains a child route (`foo.$param.bar.tsx`), convert the parent into a layout immediately:

1. Replace the parent's content with `component: () => <Outlet />` (no `beforeLoad`).
2. Move the original page content to `foo.$param.index.tsx` with route path `"…/$param/"` (trailing slash) and restore its `beforeLoad`.

This is the same pattern used for `challenges.$challengeId` → `challenges.$challengeId.index` + `challenges.$challengeId.terms`. Failing to do this makes child routes silently never render.

**Never add a page component to a route file that also has child routes.** If you need both a parent page and children, you need three files: the layout (`$param.tsx`), the index (`$param.index.tsx`), and the child (`$param.child.tsx`).

## Component Architecture (Frontend)

- **Simple, componentized components.** Break out parts that make sense into their own components — avoid bloated components with multiple responsibilities.
- **Maximize reuse — design-system mindset.** Aggressively extract primitives (Container, Section, IconBadge, CheckList, BrandMark, SectionHeading, etc.) whenever a layout/presentation pattern repeats, even within a single page. Generic primitives go in [frontend/src/components/ui/](frontend/src/components/ui/); domain composites go in `frontend/src/components/<feature>/`. When in doubt, extract.
- **Component file naming in CamelCase (PascalCase).** Component files use PascalCase: `AuthTabs.tsx`, `LoginForm.tsx`, `FormField.tsx`. Files that are not components (utils, hooks, configs) stay in kebab-case.
- **Page component co-location.** If a component is only used by one page (or a single parent component), place it in a `components/` folder adjacent to the file that uses it. Always create an `index.ts` barrel inside that folder. Example: `app/auth/components/AuthTabs.tsx` + `app/auth/components/index.ts`.
- **Fetch data in the deepest possible component.** The request belongs in the component that actually consumes the data. Only lift it to the parent if another sibling also needs the same data.
- **Server Components by default.** Keep `"use client"` at the smallest possible scope — only add it when there is state, an effect, an event handler, or a browser API.
- **Lazzu exception:** the frontend uses Vinext with the intention of `output: "export"` and Tauri in the future — in this mode, the bundle must be 100% pre-rendered client-side, so RSC does not apply and fetching happens in the browser (React Query/SWR/etc.). Treat everything here as a client component, but keep the discipline of small components, design system, and leaf-level fetching.
- **No `React.` namespace.** Never use `import * as React from "react"` or qualify types/hooks with `React.X`. Import everything by name: `import { forwardRef, useState, type HTMLAttributes, type ReactNode } from "react"`. `FormEvent`/`FormEventHandler` are deprecated in current typings — prefer an inline `onSubmit` handler so the type is inferred.
- **No `<input type="number">`.** Numeric inputs are better implemented as `type="text"` with explicit parsing and validation — `type="number"` has poor UX (scroll-to-change, inconsistent browser behavior, broken paste). Use `inputMode="numeric"` or `inputMode="decimal"` for mobile keyboard hints, parse the value with `parseFloat`/`parseInt` on change or blur, and store it as a string in local state until submission.
- **Always add masks and placeholders.** Every input that accepts a structured value (currency, percentage, date, phone, document number) must use a formatting mask — prefer `NumericFormat` from `react-number-format` for monetary/numeric fields (e.g. `prefix="R$ "`, `thousandSeparator="."`, `decimalSeparator=","`, `suffix="%"`). Every input must have a `placeholder` that shows a realistic example of the expected format (e.g. `"R$ 10.000,00"`, `"Ex: Plano Starter"`). Raw bare inputs with no context are not acceptable.
- **Always debounce text inputs.** Every `<input type="text">` and `<textarea>` must use `useDebouncedInput` from `@/hooks/use-debounced-input` — it keeps a local state that updates immediately (preserving the browser's native undo/Ctrl+Z history) and debounces the parent `onChange` callback (default 300 ms). Without this, each keystroke triggers a parent re-render that resets the browser undo stack. Pattern: `const [local, setLocal] = useDebouncedInput(form.field, v => set("field", v));` then bind `value={local}` and `onChange={e => setLocal(e.currentTarget.value)}`. For list rows, extract a row component so each row has its own local state.
- **No `alert()` or `confirm()`.** Native browser dialogs block the JS thread, ignore the app's theme, and cannot be styled. Always use the imperative helpers `showAlert(message, title?)` and `showConfirm(message, title?)` from `@/stores` — they return Promises and render `ConfirmDialog` (a baseui Modal with blurred custom backdrop mounted in `Providers`). `showConfirm` resolves `true` on confirm, `false` on cancel/close. `showAlert` resolves when the user clicks OK. Pattern: `if (!(await showConfirm(t("...")))) return;` / `void showAlert(t("..."))`.
- **No native `<select>`.** Native selects have inconsistent cross-browser styling and a cramped arrow affordance. Always use `CustomSelect` from `@/components/ui/CustomSelect` instead — it renders a `<button>` trigger with a portal-based popover (`createPortal` + `position: fixed`) so it escapes `overflow: hidden/auto` containers (e.g. modals). Never wrap `CustomSelect` in a `<label>`; use a `<div>` with the label text above it since the trigger is a button, not an input.
- **No ghost (borderless) buttons.** Never render a button without a visible border. A ghost/borderless button is invisible at rest — users can't tell it's interactive. Always use `variant: "outline"` for secondary/subtle actions; reserve `variant: "ghost"` only for icon-only toolbar buttons where the icon itself communicates interactivity, and even then ensure a clear hover background.

## Backend DTOs (Elysia / TypeBox)

**DTOs are always TypeBox schemas, never TypeScript interfaces.** The type is derived with `typeof XxxDTO.static`:

```ts
// ✅ correct
export const CreateReceiptDTO = t.Object({
    ...CreateReceiptBody.properties,
    companyId: t.Optional(t.String()),
    filename: t.String(),
    userId: t.String(),
});
export type CreateReceiptDTO = typeof CreateReceiptDTO.static;

// ❌ avoid
export interface CreateReceiptDTO {
    companyId?: string;
    filename: string;
    // ...
}
```

To compose DTOs, use a single `t.Object` with a `.properties` spread — **never** `t.Intersect`:

```ts
// ✅ correct
export const ListPriceAlertsDTO = t.Object({ ...ListPriceAlertsQuery.properties, userId: t.String() });

// ❌ avoid
export const ListPriceAlertsDTO = t.Intersect([ListPriceAlertsQuery, t.Object({ userId: t.String() })]);
```

`t.Intersect` produces poorly resolved runtime types during validation; the `.properties` spread produces a correct flat schema.

### DTO Naming vs. Elysia Option

- **Return DTO**: name it `XxxReturn` or `XxxResult` — it reflects the use-case domain, without knowledge of HTTP infrastructure.
- **Elysia controller**: pass the DTO under the `response:` key, **never** `result:`.

```ts
// ✅ correct — the Elysia key is "response"
.get("/revenue", handler, { response: GetRevenueReturn })

// ❌ wrong — "result" is not recognized by Elysia; it generates `any` types in Kubb
.get("/revenue", handler, { result: GetRevenueReturn })
```

Using `result:` makes Elysia ignore the response typing, which makes Kubb generate `XxxQueryResponse = any` in the generated SDK.

## Frontend SDK — Mandatory Rule

**Never edit files inside `frontend/src/lib/api/generated/`.** They are completely overwritten on every regeneration.

Correct flow when adding or changing an endpoint:
1. Change the backend (controller/DTO).
2. `bun run export` in the backend → updates `backend/generated/openapi.json` and `generateOpenApi.ts`.
3. `bun run generate` in the frontend → regenerates the SDK in `generated/`.

If you need a hook for an endpoint that is not yet available on the production server, place it in `frontend/src/lib/api/` (outside `generated/`) and re-export it through `frontend/src/lib/api/index.ts`.

## i18n — Mandatory Rule

The translation files in [frontend/src/i18n/locales/](frontend/src/i18n/locales/) **must remain synchronized**. Today only `pt-BR.json` exists (languages mirror the backend `SupportedLanguage` enum).

**Every time you add, rename, or remove a key, apply the change to ALL locale files in the same operation.** Never leave one locale behind another, even if the final translation still needs review — in that case, use the pt-BR string as a placeholder and leave a comment in the PR, but ensure the key structure is identical across files.

- `pt-BR` is the fallback and the ground truth for types (see [frontend/src/i18n/types.d.ts](frontend/src/i18n/types.d.ts)).
- Keys inside JSON files follow alphabetical order (linter rule).
- When introducing a new namespace, register it in [frontend/src/i18n/config.ts](frontend/src/i18n/config.ts) and in `types.d.ts`.

### Enums Are Frontend-Translatable Contracts

Backend status/error enums (e.g. bet status, payout status, error codes) exist to give the frontend predictability: the frontend translates the enum value, it never renders the raw value to the user. Whenever you add or change an enum member on the backend, add the matching translation key to **all** locale files in the same change, and render it through `t()` with the raw value as `defaultValue` (e.g. ``t(`payments.status.${payout.status}`, { defaultValue: payout.status })``). Never render a raw enum value in the UI.

## Test File Placement

- **Unit tests** live **next to the file under test** — `Foo.ts` → `Foo.test.ts` in the same directory.
- **Integration / E2E tests** (multiple units, DB, or cross-module flows) live in a `tests/` folder within the relevant module.
- **Never** name the folder `__tests__` (or any `__…__` form). The folder is always plainly named `tests`.
- Backend runs on Bun: tests use `bun:test` and `bun test`.
