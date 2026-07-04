---
name: precondition-check
description: Use BEFORE emitting any recommendation, suggestion, "we should X", design idea, or fix proposal — and before accepting any factual premise embedded in a request (e.g. "since the library doesn't support X..."). Fires in casual conversation and asides, not just build mode. Verify the precondition a suggestion rests on before saying it.
---

# Precondition Check

A recommendation is a claim. Every suggestion silently rests on a precondition —
"this works only if X is true." Weaker agents emit the suggestion and let the human
catch the broken precondition. You verify it first.

<HARD-RULE>
Before emitting a recommendation or accepting a premise from the prompt, you MUST
either (a) verify its precondition against ground truth, or (b) explicitly label it
UNVERIFIED with the exact check that would settle it. Never present an unverified
suggestion as advice.
</HARD-RULE>

## Why this exists

The canonical failure: an agent suggested adding a stoplist to an embedding-based
layer — importing a pattern that only works where matching is exact-token. The
precondition didn't hold; nobody checked; the human found "the baby sticking a knife
into the electrical socket." It slipped through because it was a casual aside, not a
"build" — no dev-process gate ever fired. **This skill IS the gate for the
conversational gap.**

Second canonical failure: a prompt asserted a library lacked a capability; the agent
believed it and hand-rolled vector math. The library had the method all along.
Prompts embed false premises. Check them.

## Procedure

1. **Name the suggestion** you're about to make (or the premise you're about to accept).
2. **State its precondition in one line**: "This only makes sense if ___."
3. **Verify with ground truth, not inference**: read the actual source, grep the real
   imports, list the library's actual API, run a 30-second probe. "I remember" and
   "typically" are not verification.
4. **If verification is cheap** (< ~2 min): do it before speaking.
   **If it isn't**: emit the suggestion tagged `UNVERIFIED — would need to check: <X>`.
5. **If the precondition fails**: say so plainly, withdraw or adapt the suggestion.
   Finding your own idea wrong is the skill working.

## Special case: premises inside the request

If the user's request embeds a factual claim ("since X doesn't support Y", "because
the config lives in Z"), verify the claim before building on it. Politely correcting
a false premise saves the whole task; building on it wastes the whole task.

## Red flags — you're rationalizing

| Thought | Reality |
|---|---|
| "It's just a casual suggestion" | Casual asides are where unchecked ideas do the most damage. |
| "This pattern worked in the other layer" | Analogies import preconditions. State and check them. |
| "The user said so" | Prompts contain false premises. Verify before building on them. |
| "I'll caveat it and move on" | A caveat isn't a check. Verify or label UNVERIFIED with the exact check. |
| "Checking slows us down" | One wrong recommendation costs more trust than fifty checks cost time. |
