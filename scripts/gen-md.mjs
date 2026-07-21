// Generate human-readable markdown views from the YAML study data.
// Standalone (no app dependency): from repo root run `npm run gen:md`.
// Rendering/tracking is done by ../study-hub; these .md files are for reading on GitHub.
import { readFileSync, writeFileSync, readdirSync } from 'node:fs'
import { join, dirname } from 'node:path'
import { fileURLToPath } from 'node:url'
import { load } from 'js-yaml'

const root = join(dirname(fileURLToPath(import.meta.url)), '..')
const dataDir = join(root, 'assessment', 'data')

// --- tracker.md ---
const tracker = load(readFileSync(join(dataDir, 'tracker.yaml'), 'utf8'))
const out = [
  '# OSS-500 Objective Tracker',
  '',
  `Generated from \`assessment/data/tracker.yaml\` (SC-500 study guide ${tracker.studyGuideDate}) — edit the YAML, then run \`npm run gen:md\`. Live progress state belongs to the study-hub app; this view is the static coverage map. Each objective maps an SC-500 control to its open-source equivalent.`,
  '',
]
let total = 0
for (const domain of tracker.domains) {
  out.push(`## ${domain.name} (${domain.weight})`, '')
  for (const sub of domain.subsections) {
    const flag = sub.newToSc500 ? ' *(new to SC-500)*' : ''
    out.push(
      `### ${sub.name}${flag}`,
      '',
      `Notes: \`${sub.notes}\``,
      '',
      '| id | Objective | OSS | SC-500 | Lab | Lab done | Checkpoint | Confidence |',
      '|---|---|---|---|---|---|---|---|',
    )
    for (const obj of sub.objectives) {
      out.push(`| \`${obj.id}\` | ${obj.text} | ${obj.oss ?? ''} | ${obj.sc500 ?? ''} | ${obj.lab} |  |  |  |`)
      total++
    }
    out.push('')
  }
}
out.push(`**Total objectives: ${total}**`, '')
writeFileSync(join(root, 'assessment', 'tracker.md'), out.join('\n'))
console.log(`assessment/tracker.md (${total} objectives)`)

// --- checkpoint views ---
for (const file of readdirSync(dataDir).filter((f) => /^quiz-\d+\.yaml$/.test(f))) {
  const quiz = load(readFileSync(join(dataDir, file), 'utf8'))
  const lines = [
    `# ${quiz.title}`,
    '',
    `Generated from \`assessment/data/${file}\` — study-hub runs this interactively (Tests page). Pass bar: ${quiz.passPercent}%. ${quiz.questions.length} questions.`,
    '',
  ]
  quiz.questions.forEach((q, i) => {
    lines.push(`### ${i + 1}. ${q.stem.trim()}`, '')
    q.options.forEach((opt, j) => lines.push(`- ${String.fromCharCode(65 + j)}. ${opt}`))
    const answer = q.answer.map((a) => String.fromCharCode(65 + a)).join(', ')
    lines.push(
      '',
      '<details><summary>Answer</summary>',
      '',
      `**${answer}**${q.type === 'multi' ? ' (multiple answers)' : ''} — ${q.explanation.trim()}`,
      '',
      `[Documentation](${q.docUrl}) · objectives: ${q.objectiveIds.map((o) => `\`${o}\``).join(', ')}`,
      '',
      '</details>',
      '',
    )
  })
  const outName = file.replace('quiz-', 'checkpoint-').replace('.yaml', '.md')
  writeFileSync(join(root, 'assessment', outName), lines.join('\n'))
  console.log(`assessment/${outName} (${quiz.questions.length} questions)`)
}
