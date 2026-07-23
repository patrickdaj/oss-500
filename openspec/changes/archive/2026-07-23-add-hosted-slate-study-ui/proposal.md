## Why

OSS-500 is content-only; today its study application (`study-hub`) runs only on a local
machine via `npm run dev`, so the curriculum can't be *used* without cloning and running it.
The public presence is a static markdown landing page that bounces visitors back to the repo.
We want a slick, hosted study UI at a public URL — dashboard, plan, notes, labs, tracker,
quizzes, search — that anyone (including the author, on any device) can use without touching
the repo, and that presents well as a portfolio piece.

## What Changes

- **Deploy the existing `study-hub` app to GitHub Pages** at `https://patrickdaj.github.io/oss-500/`,
  scoped to the **oss-500 course only**, built by a GitHub Actions workflow that lives in the
  oss-500 repo. No new app is written; study-hub's loader already renders a single course from a
  partial checkout, so scoping needs no app code change.
- **Restyle study-hub to a new "Slate" visual direction** (modern-SaaS: cool-gray neutrals,
  indigo accent) across all pages, with **light and dark** variants and a persisted theme toggle.
  Replaces the current "Study-SOC" navy theme.
- **Publish `study-hub` as a public GitHub repo** (source only) so CI can build it. Its content
  submodules for other courses are not shipped.
- **BREAKING (public presence):** the current oss-500 Pages landing page (`index.md`,
  `_config.yml`) is removed; Pages switches from "deploy from branch" to "GitHub Actions," and
  the URL now serves the app instead of a static page.
- **Cross-link** the hosted app from the oss-500 README and the `cloud-native-security-lab` blog.

## Capabilities

### New Capabilities
- `hosted-study-ui`: OSS-500 publishes its study application as a hosted, single-course GitHub
  Pages site, built from study-hub via CI and restyled to the Slate design system (light + dark),
  without duplicating the app or shipping other courses' content.

### Modified Capabilities
<!-- None. study-hub-integration's requirements (submodule sourcing, adapter, registry,
     validation-green) continue to hold unchanged; this change adds a hosting dimension rather
     than altering them. -->

## Impact

- **oss-500 repo:** new `.github/workflows/deploy-pages.yml`; removal of `index.md` and
  `_config.yml`; Pages source setting flips to GitHub Actions; README gains a hosted-app link.
- **study-hub repo (patrickdaj/study-hub, new public remote):** Slate restyle of `src/index.css`
  tokens/fonts and all page/components; a `data-theme` toggle; a `notify-oss500.yml` workflow that
  triggers the oss-500 rebuild on push (requires a `OSS500_DISPATCH_TOKEN` PAT secret). Existing
  vitest suite and `lint` must stay green.
- **Dependencies:** adds `@fontsource/inter` to study-hub; uses `actions/checkout`,
  `actions/setup-node`, `actions/upload-pages-artifact`, `actions/deploy-pages`.
- **Non-goals:** no new app features, no oss-500 content changes, no multi-course hosting, no
  auth/backend. Hosted progress starts fresh (localStorage is per-origin); content is reflected
  at build time (rebuilds on push).
