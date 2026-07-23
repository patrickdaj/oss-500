## ADDED Requirements

### Requirement: OSS-500 study UI is hosted at a public URL, scoped to one course
The oss-500 study application SHALL be published at `https://patrickdaj.github.io/oss-500/` and
SHALL render only the oss-500 course. The hosted build SHALL reuse the existing `study-hub` app
without duplicating it into oss-500 and without shipping any other course's content.

#### Scenario: Hosted app loads and defaults to oss-500
- **WHEN** a visitor opens `https://patrickdaj.github.io/oss-500/`
- **THEN** the study-hub app loads under the `/oss-500/` base path and boots directly into the
  oss-500 course dashboard

#### Scenario: Only oss-500 is present
- **WHEN** the deployed site is inspected (course switcher, routes)
- **THEN** oss-500 is the only course available; no scc-500, tf-004, or modern-security-lab
  content is included

#### Scenario: No app duplicated into oss-500
- **WHEN** the oss-500 repo is inspected
- **THEN** it contains the deploy workflow but no copy of the study-hub application source

### Requirement: The hosted site is built and deployed by CI in the oss-500 repo
A GitHub Actions workflow in the oss-500 repo SHALL build the site by checking out `study-hub`
and the oss-500 content, running the app's production build with `BASE_PATH=/oss-500/`, and
deploying the built artifact to GitHub Pages. Scoping to oss-500 SHALL rely on the app's existing
partial-checkout behavior (only oss-500 content present at build time) and SHALL NOT require app
code changes. The workflow SHALL run on pushes to oss-500's default branch, on manual dispatch,
and on a repository dispatch signalling that the app source changed.

#### Scenario: Content push rebuilds the site
- **WHEN** a commit is pushed to oss-500's default branch
- **THEN** the workflow rebuilds the app and redeploys it to Pages so the site reflects the new
  content

#### Scenario: App-source change rebuilds the site
- **WHEN** the study-hub app source changes and signals oss-500 via repository dispatch
- **THEN** the workflow rebuilds and redeploys, so the restyle/app updates appear on the hosted site

#### Scenario: Build fails closed on scope error
- **WHEN** the build runs with only oss-500 content checked out
- **THEN** the produced bundle contains exactly one course (oss-500) and the deploy publishes it

### Requirement: The study UI uses the Slate design system with light and dark themes
The study UI SHALL present the "Slate" visual system — cool-gray neutrals with a single indigo
accent — defined as design tokens, and SHALL provide both a light and a dark theme selectable by
the user, defaulting to the operating-system preference and persisting the user's choice. All UI
color, surface, and border values SHALL derive from the tokens (no hard-coded per-component
colors) so both themes render correctly everywhere.

#### Scenario: Theme defaults to OS preference
- **WHEN** a user first opens the app with no saved preference
- **THEN** the theme matches the operating-system light/dark setting

#### Scenario: Theme toggle persists
- **WHEN** the user switches the theme
- **THEN** the choice is applied immediately and restored on the next visit

#### Scenario: Both themes are complete
- **WHEN** any page is viewed in either theme
- **THEN** text, surfaces, borders, and accents render from the Slate tokens with no unthemed
  or unreadable elements

### Requirement: The public Pages entry serves the app, not a static landing page
The oss-500 GitHub Pages entry SHALL serve the hosted application. The prior static markdown
landing page SHALL be removed and the Pages build source SHALL be GitHub Actions.

#### Scenario: Root serves the app
- **WHEN** the Pages root URL is requested
- **THEN** the study-hub application is served (not the retired `index.md` landing page)

#### Scenario: Landing files removed
- **WHEN** the oss-500 repo is inspected
- **THEN** the retired `index.md` and `_config.yml` Pages landing files are absent

### Requirement: study-hub is a public, buildable source that can trigger redeploys
The `study-hub` app SHALL exist as a public GitHub repository so the oss-500 workflow can check it
out and build it, and SHALL signal the oss-500 repo to rebuild when its own source changes.

#### Scenario: CI can fetch the app source
- **WHEN** the oss-500 deploy workflow runs
- **THEN** it checks out the public study-hub repository and builds it with no private-repo
  credentials required for the app source

#### Scenario: App changes notify oss-500
- **WHEN** a commit is pushed to study-hub's default branch
- **THEN** study-hub dispatches a rebuild signal to the oss-500 repo
