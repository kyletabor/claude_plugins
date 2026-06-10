export const meta = {
  name: 'dev-process-pipeline',
  description: 'Bounded Tier-L dev-process pipeline: explore -> spec -> implement -> review -> risk-typed verify, with FIXED fan-out, turn-capped agents, and compact summary handoffs (no runaway re-reads). The deterministic engine for the dev-process skill Tier L. v1 — battle-test on a real epic before making it the default.',
  phases: [
    { title: 'Explore', detail: 'up to 3 scoped explorers -> one shared codebase digest' },
    { title: 'Spec', detail: 'one planner writes the architecture spec + legs from the digest' },
    { title: 'Implement', detail: 'one turn-capped agent per independent leg' },
    { title: 'Review', detail: 'one combined spec-compliance + quality review of the diff' },
    { title: 'Verify', detail: 'risk-typed: UI (Playwright) and/or backend (unit + integration)' },
  ],
}

// ---- args: pass {task, repo, appUrl, userFacing} OR a bare task string ----
const A = (typeof args === 'string') ? { task: args } : (args || {})
const TASK = A.task || 'No task provided — describe the feature in args.task'
const REPO = A.repo || '.'
const APP_URL = A.appUrl || ''
const USER_FACING = A.userFacing === true || !!APP_URL

// Right-size the explorer fan-out to the token budget (the anti-blowup guard).
const EXPLORERS = (budget.total && budget.total < 300000) ? 1 : 3

// Every agent is told to cap itself: there is no per-agent maxTurns in the Workflow API,
// so the cap is (a) a hard prompt instruction and (b) the fixed, non-looping structure.
const CAP = 'HARD LIMIT: finish within ~20 tool calls. If blocked after 2 attempts, STOP and return what you have with a clear blocker note. Do NOT re-read the whole codebase — work from the scope/paths you were given.'

const DIGEST_SCHEMA = { type: 'object', required: ['summary', 'files'], properties: {
  lens: { type: 'string' },
  summary: { type: 'string', description: '<=1500 tokens. Distilled findings only — NOT raw file dumps.' },
  files: { type: 'array', items: { type: 'string' }, description: 'relevant file paths' },
} }

const SPEC_SCHEMA = { type: 'object', required: ['spec', 'legs', 'acceptance'], properties: {
  spec: { type: 'string', description: 'concise architecture spec (goal, design, files to change)' },
  legs: { type: 'array', items: { type: 'object', properties: {
    name: { type: 'string' }, scope: { type: 'string' }, files: { type: 'array', items: { type: 'string' } },
    independent: { type: 'boolean', description: 'true if it shares no files with other legs' } } } },
  acceptance: { type: 'array', items: { type: 'string' }, description: 'testable acceptance criteria' },
} }

const IMPL_SCHEMA = { type: 'object', required: ['leg', 'done', 'summary'], properties: {
  leg: { type: 'string' }, done: { type: 'boolean' },
  summary: { type: 'string', description: 'what was built + test result + any deviation (compact)' },
  commit: { type: 'string' },
} }

const REVIEW_SCHEMA = { type: 'object', required: ['verdict', 'findings'], properties: {
  verdict: { type: 'string', enum: ['APPROVE', 'REJECT'] },
  findings: { type: 'array', items: { type: 'object', properties: {
    severity: { type: 'string' }, file: { type: 'string' }, issue: { type: 'string' } } } },
} }

const VERIFY_SCHEMA = { type: 'object', required: ['pass', 'evidence'], properties: {
  mode: { type: 'string' }, pass: { type: 'boolean' },
  evidence: { type: 'string', description: 'screenshot path / DOM assertion / test command output' },
  failures: { type: 'array', items: { type: 'string' } },
} }

// ---------- Phase 1: Explore (fixed fan-out, barrier — spec needs all digests) ----------
phase('Explore')
const lenses = [
  { key: 'patterns', p: `Find existing features similar to this task and the conventions to follow. Task: ${TASK}` },
  { key: 'integration', p: `Find where this task integrates: APIs, data models, entry points, files to modify. Task: ${TASK}` },
  { key: 'tests', p: `Find how tests are structured here (unit/integration/e2e patterns, runner, commands). Task: ${TASK}` },
].slice(0, EXPLORERS)

const digests = (await parallel(lenses.map(l => () =>
  agent(`You are a scoped codebase explorer for repo ${REPO}. ${l.p}\n${CAP}\nReturn a DISTILLED digest (findings + relevant file paths), not raw file contents.`,
    { label: `explore:${l.key}`, phase: 'Explore', agentType: 'Explore', schema: DIGEST_SCHEMA })
))).filter(Boolean)

// ---------- Phase 2: Spec (single planner, consumes digests) ----------
phase('Spec')
const spec = await agent(
  `Write a concise architecture spec for this task, then break it into implementation legs.\n\nTASK: ${TASK}\nREPO: ${REPO}\n\nCODEBASE DIGESTS (work from these — do NOT re-explore the whole repo):\n${JSON.stringify(digests)}\n\nMark each leg 'independent: true' only if it shares no files with another leg. Keep the spec tight. ${CAP}`,
  { label: 'spec', phase: 'Spec', schema: SPEC_SCHEMA })

const legs = (spec.legs && spec.legs.length) ? spec.legs : [{ name: 'implement', scope: TASK, files: [], independent: true }]

// ---------- Phase 3: Implement (one capped agent per leg; independent legs in parallel) ----------
phase('Implement')
const implThunks = legs.map((leg, i) => () =>
  agent(`Implement this leg of the spec in repo ${REPO}. Follow the spec exactly; write tests alongside code; commit when done.\n\nLEG: ${leg.name}\nSCOPE: ${leg.scope}\nFILES: ${(leg.files || []).join(', ') || '(determine from scope)'}\n\nSPEC:\n${spec.spec}\n\n${CAP}`,
    { label: `impl:${leg.name || i}`, phase: 'Implement', schema: IMPL_SCHEMA })
)
// Independent legs can run together; if any leg is non-independent, run sequentially to avoid file conflicts.
const allIndependent = legs.every(l => l.independent !== false)
let impls
if (allIndependent) {
  impls = (await parallel(implThunks)).filter(Boolean)
} else {
  impls = []
  for (const t of implThunks) { const r = await t(); if (r) impls.push(r) }
}

// ---------- Phase 4: Review (one combined pass over the diff) ----------
phase('Review')
const review = await agent(
  `Review the implementation against the spec in repo ${REPO}. Run \`git diff\` to see changes. Check: spec-compliance, code quality, test coverage, security. ONE pass — be decisive.\n\nSPEC:\n${spec.spec}\n\nACCEPTANCE:\n${JSON.stringify(spec.acceptance)}\n\nIMPLEMENTATION SUMMARIES:\n${JSON.stringify(impls)}\n\n${CAP}`,
  { label: 'review', phase: 'Review', schema: REVIEW_SCHEMA })

// ---------- Phase 5: Verify (risk-typed; NOT the builder) ----------
phase('Verify')
const verifyThunks = []
if (USER_FACING) {
  verifyThunks.push(() => agent(
    `Independently verify this feature from the USER's perspective. App URL: ${APP_URL}. For EACH acceptance criterion, load the app like a user, perform the action, check the observable result, screenshot it. You CANNOT edit code.\n\nACCEPTANCE:\n${JSON.stringify(spec.acceptance)}\n\n${CAP}`,
    { label: 'verify:ui', phase: 'Verify', agentType: 'dev-process:independent-verifier', schema: VERIFY_SCHEMA }))
}
// Backend / integration verification always runs (a green machine + integration gate is the floor).
verifyThunks.push(() => agent(
  `Independently verify this change at the integration level in repo ${REPO}. Do NOT trust the builder. Run the unit suite AND the integration/workflow test(s) that exercise the REAL end-to-end flow (real inputs->outputs, not mocks). If none covers this path, run or write one. Confirm each acceptance criterion. You CANNOT ship — run, inspect, report with command output.\n\nACCEPTANCE:\n${JSON.stringify(spec.acceptance)}\n\n${CAP}`,
  { label: 'verify:backend', phase: 'Verify', agentType: 'verification-hooks:independent-verifier', schema: VERIFY_SCHEMA }))

const verdicts = (await parallel(verifyThunks)).filter(Boolean)

return {
  task: TASK,
  explorers: digests.length,
  legs: legs.length,
  reviewVerdict: review.verdict,
  reviewFindings: review.findings,
  verification: verdicts,
  allPass: review.verdict === 'APPROVE' && verdicts.every(v => v.pass),
}
