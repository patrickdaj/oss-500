// Link-specificity lint for OSS-500 content (the `resource-citation` standard).
//
// Fails when a Markdown link in `domains/**` or `labs/**` points at a generic
// target — a host-only URL or a known documentation-root / landing-page pattern —
// UNLESS the link's line is marked `(reference)`. See the "How resources are cited"
// section of domains/standards-map.md for the standard this enforces.
//
// Standalone: from the repo root run `node scripts/lint-links.mjs`.
// Mirrored in study-hub's scripts/lint-content.mjs so `npm run lint:content` catches
// the same violations against the content submodule.
import { readFileSync, readdirSync, statSync } from 'node:fs'
import { join, dirname, relative } from 'node:path'
import { fileURLToPath } from 'node:url'

const root = join(dirname(fileURLToPath(import.meta.url)), '..')
const ROOTS = ['domains', 'labs']

// A link line carrying this marker is an intentional canonical/navigational
// reference (a tool home, framework site, spec URL) and is exempt.
const REFERENCE = /\(reference(\s*[—-][^)]*)?\)/

// Markdown inline links: [text](url). Capture text + url.
const LINK = /\[([^\]]*)\]\((https?:\/\/[^)\s]+)\)/g

// Doc-root / landing-page path patterns that carry no "what to read" signal.
// Host-only URLs are handled separately (segment count 0).
const DOCROOT = [
  /\/docs\/?$/i,               // …/docs, …/docs/
  /\/docs\/concepts\/?$/i,     // …/docs/concepts/
  /\/docs\/latest\/?$/i,       // …/docs/latest/
  /\/latest\/docs\/?$/i,       // …/latest/docs/
  /\/latest\/?$/i,             // …/latest/  (versioned doc root)
  /\/(overview\/)?intro\/?$/i, // …/intro, …/overview/intro/
  /\/get-started\/?$/i,        // …/get-started/  (onboarding hub)
  /\/getting-started\/?$/i,
]

function pathOf(url) {
  const m = url.match(/^https?:\/\/[^/]+(\/[^?#]*)?/)
  return (m && m[1]) || '/'
}
function segCount(p) {
  return p.replace(/\/+$/, '').split('/').filter(Boolean).length
}
function isGeneric(url) {
  // A non-empty `#fragment` names the exact section — that IS the deep-link the
  // standard asks for (`deep-url#anchor`), even on a single-page or doc-root site.
  if (/#\S/.test(url)) return null
  const p = pathOf(url)
  if (segCount(p) === 0) return 'host-only URL'
  for (const re of DOCROOT) if (re.test(p)) return `documentation-root pattern (${p})`
  return null
}

function walk(dir) {
  const out = []
  for (const name of readdirSync(dir)) {
    const full = join(dir, name)
    if (statSync(full).isDirectory()) out.push(...walk(full))
    else if (name.endsWith('.md')) out.push(full)
  }
  return out
}

const errors = []
for (const r of ROOTS) {
  const base = join(root, r)
  let files
  try { files = walk(base) } catch { continue } // root may not exist
  for (const file of files) {
    const rel = relative(root, file)
    const lines = readFileSync(file, 'utf8').split('\n')
    lines.forEach((line, i) => {
      if (REFERENCE.test(line)) return // whole line is an exempt reference
      for (const m of line.matchAll(LINK)) {
        const [, text, url] = m
        const reason = isGeneric(url)
        if (reason) errors.push(`${rel}:${i + 1}: ${reason} — [${text}](${url}) — deep-link + name the section, or mark (reference)`)
      }
    })
  }
}

if (errors.length) {
  console.error(`lint:links FAILED (${errors.length} generic link${errors.length > 1 ? 's' : ''}):\n` + errors.map((e) => '  - ' + e).join('\n'))
  process.exit(1)
}
console.log('lint:links OK — no generic links in domains/** or labs/**')
