## Context

OSS-500 is content-only. The study application is `study-hub` (React + Vite + Tailwind), a
separate local-first repo on this machine that ingests each course as a git submodule under
`content/<course>/` and renders any course through one shared UI. oss-500 is already wired in as
`content/oss-500` with an adapter and registry entry (see the `study-hub-integration` capability).

study-hub is **already engineered for Pages**: `vite.config.ts` reads `base: process.env.BASE_PATH ?? '/'`
and `src/content/loader.ts` filters the course registry to courses actually present
(`// a submodule could be absent in a partial checkout`). It has **no GitHub remote** and has never
been hosted. Its current theme is dark-first "Study-SOC" navy.

oss-500 currently deploys a static Jekyll landing page (`index.md` + `_config.yml`) to Pages via
"deploy from branch." This change replaces that with the hosted app.

Two Slate mockups (Dashboard, Notes reading view) were built and approved before this change.

**Cross-repo note:** OpenSpec planning artifacts live in oss-500, but implementation edits span
two repos — the Slate restyle commits in **study-hub**, the deploy workflow commits in **oss-500**.
tasks.md marks each task with its repo.

## Goals / Non-Goals

**Goals:**
- Hosted, single-course oss-500 study UI at `https://patrickdaj.github.io/oss-500/`, usable
  without cloning the repo.
- Reuse study-hub as-is for scoping (partial checkout → one course); no app logic changes for
  course selection.
- Restyle study-hub to the Slate design system across all pages, with light + dark themes.
- Automatic redeploy on both content (oss-500) and app (study-hub) changes.

**Non-Goals:**
- No new app features, no oss-500 content changes, no multi-course hosting, no auth/backend.
- No migration of local `localStorage` progress to the hosted origin.
- No conversion of study-hub off its own (superpowers) workflow beyond adding a remote + CI.

## Decisions

### D1: Build in oss-500's workflow by checking out both repos (vs. deploy from study-hub)
The Actions workflow lives in **oss-500** and does two checkouts: study-hub (app) at the root and
oss-500 (content) into `content/oss-500/`. Then `npm ci && BASE_PATH=/oss-500/ npm run build`,
then `upload-pages-artifact` + `deploy-pages`.
- **Why:** the user wants the app served at the oss-500-branded URL. Building in oss-500's own
  workflow keeps deploy ownership with the content repo and avoids cross-repo artifact pushes.
- **Scoping for free:** a fresh study-hub checkout has no submodule content; we place only
  oss-500 under `content/oss-500/`, so `loader.ts`'s existing filter yields a single course.
- **Alternative rejected:** deploy from study-hub's own Pages to `…/study-hub/` — simpler, but
  wrong URL and splits the public presence from the course repo.

### D2: study-hub is a public repo (vs. private + PAT for checkout)
Publishing study-hub's source lets `actions/checkout` fetch it with no extra credentials. The
source is just the React app; other courses' *content* is never shipped (only oss-500 is placed in
`content/`).
- **Alternative rejected:** private study-hub + a PAT with cross-repo read — more secrets, more
  friction, no real benefit since the app source is not sensitive.

### D3: Redeploy triggers — push + dispatch + manual
Workflow triggers: `push` to oss-500 `main`, `workflow_dispatch`, and
`repository_dispatch: study-hub-updated`. study-hub adds `notify-oss500.yml` that fires the
dispatch on its own push, using a `OSS500_DISPATCH_TOKEN` PAT secret.
- **Why:** content lives in oss-500 (push trigger) but the app lives in study-hub (dispatch), so
  both sources must be able to refresh the one site. Manual dispatch is the escape hatch.
- **Trade-off:** the dispatch needs a PAT. If the user prefers zero secrets, drop
  `notify-oss500.yml` and rebuild via content pushes + manual dispatch only (documented fallback).

### D4: Slate as design tokens with a `data-theme` dark override
Replace the navy tokens in `src/index.css`. Light Slate lives in Tailwind's `@theme`; dark Slate
lives in a `:root[data-theme="dark"] { … }` block. A small boot script sets `data-theme` from
`localStorage` (`study-hub:theme`) or `prefers-color-scheme`; a Settings/sidebar toggle updates it.
Fonts move to **Inter** (`@fontsource/inter`) for sans; **IBM Plex Mono** stays for code.
- **Why tokens-only:** components already consume semantic color classes (`bg-surface`, `text-ink`,
  `border-edge`); recoloring the tokens restyles most surfaces at once and makes the dark variant
  near-free. Per-component polish then matches the mockups.
- **Alternative rejected:** Tailwind `dark:` variant utilities everywhere — more churn across many
  components than a single token override block.

### D5: Restyle scope = all pages, presentation-only
Retheme `Dashboard`, `Plan`, `Browse` (Notes/Labs), `DocPage` (+ right rail), `Tracker`, `Tests`,
`QuizRun`, `Search`, `Settings`, and shared components (`CourseSwitcher`, `Markdown`, `Backlinks`,
`CoverageGrid`). No routing/behavior changes. Existing vitest tests must stay green; only
assertions coupled to old class names/copy may be adjusted.

## Risks / Trade-offs

- **PAT management for the app-change trigger (D3)** → Keep it optional; document the
  no-secret fallback (content-push + manual rebuild). Store the PAT as a repo secret, least scope
  (`repository_dispatch` only).
- **Hosted progress starts empty** (localStorage is per-origin) → Expected and documented; the
  hosted site becomes the source of truth going forward. Local dev is unaffected.
- **Tests coupled to old styling could break** → The restyle is token/class-level; run
  `npm test` after each page and fix only assertions tied to removed classes/copy, not behavior.
- **A future second course accidentally shipped** → The build checks out only `content/oss-500`;
  if that ever changes, the single-course scenario in the spec fails the eyeball check. Keep the
  workflow's content checkout path pinned to `content/oss-500`.
- **Pages source flip is one-way-ish** → Switching to "GitHub Actions" retires the branch build;
  rollback is re-adding `index.md`/`_config.yml` and flipping the source back (documented).

## Migration Plan

1. Restyle study-hub (Slate tokens + fonts + theme toggle + all pages); keep tests/lint green.
2. Create public `patrickdaj/study-hub`; push `main`.
3. Add oss-500 `deploy-pages.yml`; push; switch oss-500 Pages source to GitHub Actions; remove
   `index.md`/`_config.yml`.
4. Add study-hub `notify-oss500.yml` + `OSS500_DISPATCH_TOKEN` secret (or take the no-secret
   fallback).
5. Verify the hosted site (200, Slate dashboard, navigation, theme toggle, single course).
6. Update oss-500 README + `cloud-native-security-lab` blog links to the hosted app.

**Rollback:** flip oss-500 Pages source back to "deploy from branch" and restore `index.md` +
`_config.yml`.
