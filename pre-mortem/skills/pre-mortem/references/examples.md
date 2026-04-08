# Pre-Mortem Examples

Three examples showing different task types, different depths, different structures.
These demonstrate the THINKING PROCESS — do not copy them as templates.

Notice: each example emphasizes different things based on what matters for that task.

---

## Example 1: Data Pipeline (Standard Tier)

**Context:** Extracting friction events from customer session transcripts using LLM prompts,
then synthesizing across sessions to find patterns.

### Pre-Mortem Card

**Task:** Extract friction events from 847 transcripts and synthesize into actionable patterns.

**What makes this succeed:**
- Extraction prompt finds friction that a human reader would also identify
- Events include enough context (what happened before, customer reaction) to be actionable
- Synthesis groups genuinely related events, not just keyword matches
- Final output gives product team specific, prioritized problems to fix

**What failure looks like — it already happened, explain why:**

The pipeline ran. It produced a beautiful JSON file with 2,400 friction events and 47 pattern
clusters. The product team read it and said "this is useless." Why?

1. **Hallucinated friction.** The LLM inferred frustration from neutral statements. "I'll check
   on that" became "customer expressed uncertainty about process." 60% of events weren't real
   friction — they were the LLM projecting sentiment onto mundane conversation.

2. **Context-free events.** Each event said WHAT happened but not WHY it matters. "Customer asked
   to repeat information" — was this a system failure or normal conversation? Without the before/after
   context, the product team can't tell signal from noise.

3. **Meaningless clusters.** The synthesis grouped by surface keywords ("billing" cluster, "login"
   cluster) instead of root causes. Ten different symptoms of the same auth flow bug ended up in
   five different clusters. The real pattern was invisible.

**Assumptions to validate:**
- [ ] LLM can distinguish genuine friction from neutral conversation (test: sample 20 transcripts, compare LLM output to human annotation)
- [ ] Session metadata (timestamps, agent IDs) is complete enough to reconstruct context (test: spot-check 10 sessions)
- [ ] 847 transcripts can be processed within API rate limits and budget (test: estimate token count and cost before running)

**Verification plan:**
- Gold standard: Human-annotate 20 transcripts. Compare LLM extraction against human labels. Precision > 0.8, Recall > 0.6.
- Spot-check synthesis: For the top 5 clusters, read 3 source events each. Do they genuinely belong together?
- Absence check: Pick 5 transcripts with KNOWN friction (pre-identified). Did the pipeline find them?

---

## Example 2: Feature Implementation (Standard Tier)

**Context:** Adding real-time notification system to an existing Express/React app. WebSocket-based,
needs to handle reconnection and offline queueing.

### Pre-Mortem Card

**Task:** Implement WebSocket notification system with offline queueing.

**Success criteria:**
1. When a notification is sent while user is connected, it appears within 2 seconds
2. When a notification is sent while user is disconnected, it appears within 5 seconds of reconnection
3. When the WebSocket server restarts, clients reconnect automatically without user action
4. When 100 concurrent users are connected, notification latency stays under 5 seconds (p95)
5. Existing REST API endpoints continue to function — zero regression

**This project failed. Here's how:**

The demo looked great. Notifications popped up in real-time during the demo. Then we deployed
to staging and everything fell apart.

1. **Reconnection logic was never tested under real conditions.** The dev tested by stopping and
   starting the local server. In staging, the load balancer sends a TCP RST, not a clean close.
   The client's `onclose` handler never fires. Users stare at a dead connection forever.

2. **Offline queue grew unbounded.** A user left their laptop closed for a weekend. Monday morning,
   they opened it and got 847 notifications in 3 seconds. The browser tab crashed. There was no
   TTL on queued messages and no batch delivery limit.

3. **The notification table had no index on user_id.** Worked fine with 50 test users. With 10,000
   production users, the query to fetch undelivered notifications took 8 seconds. The WebSocket
   connection timed out waiting for the initial payload.

**Risks and mitigations:**

| Risk | Likelihood | Mitigation |
|------|-----------|------------|
| Load balancer interferes with WebSocket upgrade | High | Test with actual nginx/ALB config, not just localhost |
| Memory leak from uncleaned event listeners on reconnect | Medium | Write teardown test: connect/disconnect 100 times, check heap |
| Race condition between REST and WS delivering same notification | Medium | Deduplicate by notification ID on client side |

**Verification:** Playwright test that disconnects network, queues 3 notifications, reconnects, verifies all 3 arrive in order. Run against staging config, not dev.

---

## Example 3: Research / Analysis Task (Light-to-Standard Tier)

**Context:** Investigating why the GraphRAG entity extraction produces low-quality knowledge graphs.
Need to determine root cause and recommend fixes.

### Pre-Mortem Card

**Task:** Diagnose GraphRAG entity extraction quality issues and recommend fixes.

**How I'll know this investigation succeeded:**
- Root cause is identified with evidence (not just a theory)
- Recommendations are specific enough to implement (not "improve the prompt")
- I can point to concrete examples of bad extraction AND explain why each one went wrong
- The fix addresses the root cause, not just the symptoms I happened to look at

**How this investigation fails:**

I spend 3 hours reading code and produce a report that says "the prompt needs to be more specific
about entity types and relationship constraints." Kyle reads it and asks "which entity types? what
constraints? show me the bad outputs." I can't answer because I analyzed the code without looking
at actual outputs.

Alternatively: I look at 5 bad outputs, find 5 different surface issues, propose 5 point fixes,
and miss that they all stem from the same root cause — the prompt doesn't ground extraction in
the actual transcript text, so the LLM fills in plausible-sounding entities from its training data.

**Key assumption:** The extraction quality issue is in the prompt/model, not in the input data
quality. Validate by checking: are the source transcripts clean enough to extract from? If they're
garbled ASR output, better prompts won't help.

**Verification:** Present findings to Kyle with:
1. At least 5 concrete examples of bad extraction with specific diagnosis for each
2. Evidence that the root cause explains the majority of failures (not just the examples I picked)
3. A recommended fix specific enough that an implementation agent could execute it without further research

---

## What These Examples Show

**Different structures:** Example 1 leads with a narrative failure story. Example 2 uses a
criteria table plus failure narrative. Example 3 is more conversational and reflective.
All three are valid. The structure should fit the task.

**Specific over generic:** "LLM inferred frustration from neutral statements" not "model could
make errors." "Load balancer sends TCP RST" not "network issues could occur." Specificity is
what makes pre-mortems useful.

**Testable criteria:** Every success criterion can be checked by a verifier who wasn't involved
in the work. "Precision > 0.8 against human annotations" is testable. "High quality extraction"
is not.

**Assumptions surfaced:** Each example identifies something the agent is relying on but hasn't
verified. These are the landmines that blow up projects when they turn out to be wrong.

**Failure as narrative:** The failure sections tell a story — "it already happened, here's why."
This is the prospective hindsight technique. It produces richer analysis than "what could go wrong?"
