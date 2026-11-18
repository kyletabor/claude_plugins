export const meta = {
  name: 'dev-process-pipeline',
  description: 'Bounded Tier-L dev-process pipeline: explore -> spec -> implement -> review -> risk-typed verify, with FIXED fan-out, turn-capped agents, and compact summary handoffs (no runaway re-reads). The default engine for a Tier-L piece in the dev-process skill; every helper is a hard-capped agent type.',
  phases: [
    { title: 'Explore', detail: '1 scoped explorer by default (args.explorers up to 3) -> one shared codebase digest' },
    { title: 'Spec', detail: 'one planner writes the architecture spec + legs from the digest' },
    { title: 'Implement', detail: 'one hard-capped piece-builder per leg, at most MAX_LEGS (2) legs' },
    { title: 'Review', detail: 'one combined spec-compliance + quality review of the diff' },
    { title: 'Verify', detail: 'risk-typed: UI (Playwright) and/or backend (unit + integration)' },
  ],
}

// ---- args: pass {task, repo, appUrl, userFacing, realData, explorers} OR a bare task string ----
const A = (typeof args === 'string') ? { task: args } : (args || {})
const TASK = A.task || 'No task provided — describe the feature in args.task'
const REPO = A.repo || '.'
const APP_URL = A.appUrl || ''
const USER_FACING = A.userFacing === true || !!APP_URL
const REAL_DATA = A.realData || ''

// One explorer by default; up to 3 only when asked for (a truly unfamiliar codebase). Anti-blowup guard.
const EXPLORERS = Math.max(1, Math.min(3, Number(A.explorers) || 1))

// Hard caps come from the agent types: dev-process:piece-builder (maxTurns 50), piece-reviewer (25) and
// independent-verifier (30) set maxTurns in their frontmatter, so Claude Code stops them. The prompt line
// below and the fixed, non-looping structure are the backstop (the Explore and Spec agents have no type cap).
const CAP = 'LIMIT: aim to finish within ~20 tool calls (builders ~30; Claude Code hard-stops builders at 50 and reviewers at 25). If blocked after 2 attempts, STOP and return what you have with a clear blocker note. Do NOT re-read the whole codebase — work from the scope/paths you were given.'

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

// A Tier-L piece gets at most MAX_LEGS builders. More legs means the piece is too big: stop and report
// so the lead re-cuts it, instead of quietly spawning more builders (the up-to-10-helpers failure).
const MAX_LEGS = 2
if (legs.length > MAX_LEGS) {
  return {
    task: TASK, tooBig: true, legs: legs.map(l => l.name), allPass: false,
    message: `The planner split this piece into ${legs.length} legs; the cap is ${MAX_LEGS}. Nothing was built. Re-cut it into smaller pieces and run each one on its own.`,
  }
}

// ---------- Phase 3: Implement (one capped agent per leg; independent legs in parallel) ----------
phase('Implement')
const implThunks = legs.map((leg, i) => () =>
  agent(`Implement this leg of the spec in repo ${REPO}. Follow the spec exactly; write tests alongside code; commit when done.\n\nLEG: ${leg.name}\nSCOPE: ${leg.scope}\nFILES: ${(leg.files || []).join(', ') || '(determine from scope)'}\n\nSPEC:\n${spec.spec}\n\n${CAP}`,
    { label: `impl:${leg.name || i}`, phase: 'Implement', agentType: 'dev-process:piece-builder', schema: IMPL_SCHEMA })
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
  { label: 'review', phase: 'Review', agentType: 'dev-process:piece-reviewer', schema: REVIEW_SCHEMA })

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
  `Independently verify this change at the integration level in repo ${REPO}. Do NOT trust the builder. Run the unit suite AND the integration/workflow test(s) that exercise the REAL end-to-end flow (real inputs->outputs, not mocks). If none covers this path, run or write one. Confirm each acceptance criterion.${REAL_DATA ? ` Then run it on the owner's REAL data at ${REAL_DATA} (not fixtures) and report what they would see.` : ''} You CANNOT ship — run, inspect, report with command output.\n\nACCEPTANCE:\n${JSON.stringify(spec.acceptance)}\n\n${CAP}`,
  { label: 'verify:backend', phase: 'Verify', agentType: 'dev-process:independent-verifier', schema: VERIFY_SCHEMA }))

const verdicts = (await parallel(verifyThunks)).filter(Boolean)

return {
  task: TASK,
  explorers: digests.length,
  legs: legs.length,
  reviewVerdict: review.verdict,
  reviewFindings: review.findings,
  verification: verdicts,
  realDataChecked: !!REAL_DATA,
  allPass: review.verdict === 'APPROVE' && verdicts.every(v => v.pass),
}
