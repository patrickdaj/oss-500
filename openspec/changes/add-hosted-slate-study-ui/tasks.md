# Tasks

Repo tags: **[SH]** = commit in `study-hub`, **[OSS]** = commit in `oss-500`.
Keep study-hub's `npm test` and `npm run lint` green after each SH group.

## 1. Slate design tokens & theming (SH)

- [ ] 1.1 Add `@fontsource/inter` to study-hub `package.json`; import Inter weights (400/500/600/700) in `src/index.css`; keep IBM Plex Mono imports; drop Space Grotesk + IBM Plex Sans imports
- [ ] 1.2 Replace the `@theme` block in `src/index.css` with Slate **light** tokens (bg #f6f7f9, surface #fff, surface-2 #f1f3f7, edge #e5e8ef, ink #0f172a, ink-muted #64748b, accent #4f46e5, accent-soft #ecebfd, accent-ink #fff, ok #059669, ok-soft #d9f4ea, warn #d97706, violet #7c3aed, violet-soft #f0eafe); set `--font-display`/`--font-sans` to Inter
- [ ] 1.3 Add a `:root[data-theme="dark"] { … }` override block with Slate **dark** tokens (bg #0e1017, surface #161922, surface-2 #1e222d, edge #2a2f3c, ink #e8ebf2, ink-muted #94a0b8, accent #7c73f0, accent-soft #241f3d, accent-ink #0e1017, ok #34d399, ok-soft #123026, warn #fbbf24, violet #a78bfa, violet-soft #241f3d)
- [ ] 1.4 Add a pre-hydration theme boot snippet in `index.html` that sets `document.documentElement.dataset.theme` from `localStorage['study-hub:theme']` else `matchMedia('(prefers-color-scheme: dark)')` (avoids flash-of-wrong-theme)
- [ ] 1.5 Add a `useTheme` hook/util (get/set/toggle) that writes `study-hub:theme` and updates `data-theme`; add a theme toggle control in Settings and the sidebar
- [ ] 1.6 Update the `.ref-link` styles in `src/index.css` to the Slate accent pill; verify visually in light and dark
- [ ] 1.7 Run `npm test` and `npm run lint`; fix any assertions coupled to removed theme classes/copy

## 2. Restyle the shell & Dashboard (SH)

- [ ] 2.1 Restyle the sidebar/nav in `src/App.tsx`: gradient "O5" logo tile + wordmark, course switcher pill, nav grouped under **Study** (Dashboard, Plan, Notes, Labs) and **Assess** (Tracker, Tests, Search, Settings) with count badges; active = accent-soft bg + accent text (match approved mockup)
- [ ] 2.2 Restyle `src/pages/Dashboard.tsx`: four stat cards (Objectives, Labs, Quiz banks, Standards) with value/total + status chip + progress bar; "Domain progress" list (rank tile + bar + %); "Continue" card (last note + next lab with file-path code chips)
- [ ] 2.3 Restyle `src/components/CourseSwitcher.tsx` and `src/components/CoverageGrid.tsx` to Slate
- [ ] 2.4 Run `npm test` + `npm run lint`; fix coupled assertions; commit

## 3. Restyle the reading view & content components (SH)

- [ ] 3.1 Restyle `src/pages/DocPage.tsx` to the Notes reading view: breadcrumb, title + "Mark complete" toggle, standards/mapping chips, ≤760px prose column, and a right rail with **On this page** TOC, checkable **Objectives**, and **Backlinks**
- [ ] 3.2 Restyle `src/components/Markdown.tsx`: prose spacing/typography, dark code blocks, and a violet **"Attack it"** callout treatment for purple-team blocks; restyle `src/components/Backlinks.tsx`
- [ ] 3.3 Run `npm test` + `npm run lint`; fix coupled assertions; commit

## 4. Restyle remaining pages (SH)

- [ ] 4.1 Restyle `src/pages/Plan.tsx` and `src/pages/Browse.tsx` (Notes/Labs listings) to Slate
- [ ] 4.2 Restyle `src/pages/Tracker.tsx` and `src/pages/Search.tsx` to Slate
- [ ] 4.3 Restyle `src/pages/Tests.tsx` and `src/pages/QuizRun.tsx` to Slate
- [ ] 4.4 Restyle `src/pages/Settings.tsx` to Slate (including the theme toggle from 1.5)
- [ ] 4.5 Full visual pass of every page in light and dark against the mockups; run `npm test` + `npm run lint`; commit

## 5. Local build verification (SH)

- [ ] 5.1 Simulate the CI partial checkout locally (only `content/oss-500` present) and run `BASE_PATH=/oss-500/ npm run build`; confirm `dist/` builds and the bundle boots into oss-500 as the only course
- [ ] 5.2 `npm run preview` and click through Dashboard → Notes → Labs → Tracker → Tests in both themes; confirm no unthemed elements

## 6. Publish study-hub as a public repo (SH)

- [ ] 6.1 Create public repo `patrickdaj/study-hub` via `gh repo create` and push `main` (verify `.gitmodules` local-path URLs are harmless to a public clone; CI does not use them)
- [ ] 6.2 Add `.github/workflows/notify-oss500.yml`: on `push` to `main`, POST a `repository_dispatch` (`event_type: study-hub-updated`) to `patrickdaj/oss-500` using secret `OSS500_DISPATCH_TOKEN`
- [ ] 6.3 Create a fine-scoped PAT (repository_dispatch on oss-500) and add it to study-hub as the `OSS500_DISPATCH_TOKEN` secret

## 7. oss-500 deploy pipeline (OSS)

- [ ] 7.1 Add `.github/workflows/deploy-pages.yml`: triggers `push` (main), `workflow_dispatch`, `repository_dispatch` (types: [study-hub-updated]); Pages permissions + concurrency
- [ ] 7.2 Job steps: `actions/checkout` study-hub (public) at root → `actions/checkout` oss-500 into `content/oss-500` → `actions/setup-node` (Node 22) → `npm ci` → `BASE_PATH=/oss-500/ npm run build`
- [ ] 7.3 Deploy steps: `actions/upload-pages-artifact` (`dist/`) → `actions/deploy-pages`
- [ ] 7.4 Remove `index.md` and `_config.yml` from oss-500 (retire the landing page)
- [ ] 7.5 Push oss-500; in repo Settings → Pages, switch source to "GitHub Actions"; trigger the workflow (push or manual)

## 8. Verify & cross-link

- [ ] 8.1 Confirm `https://patrickdaj.github.io/oss-500/` returns 200 and renders the Slate dashboard for oss-500 only
- [ ] 8.2 On the hosted site: navigate Dashboard → Plan → Notes → Labs → Tracker → Tests → Search, and toggle light/dark; confirm all work
- [ ] 8.3 Verify the redeploy triggers: a trivial oss-500 content push rebuilds; a study-hub push fires the dispatch and rebuilds (or, if PAT skipped, document the manual-rebuild fallback)
- [ ] 8.4 [OSS] Update the oss-500 README to link the hosted app; [cloud-native-security-lab] update the blog Welcome post + oss-500 links to point at the hosted app
- [ ] 8.5 Run `openspec validate add-hosted-slate-study-ui` and confirm the change is ready to archive
