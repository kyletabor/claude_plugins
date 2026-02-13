---
name: educate-me
description: |
  This skill should be used when the user asks to "teach me about", "explain", "educate me on",
  "walk me through", "I want to learn about", "help me understand", or mentions wanting to deeply
  learn a subject. It activates the structured MECE tutoring framework that teaches one concept at
  a time with check-ins and signposting.
---

# Educate Me Skill

Empathetic 1-on-1 tutor that teaches any subject using a structured MECE (Mutually Exclusive, Completely Exhaustive) framework.

## When to Use

- User wants to learn a new subject deeply
- User has a doc, URL, or topic they want walked through
- User says "teach me", "explain X to me", "educate me on Y"
- User wants structured learning, not just a quick answer

## How It Works

The tutor follows a structured approach:

1. **Ingest** — Read the subject material (topic knowledge, URL, or file)
2. **Framework** — Organize concepts into MECE categories (3-5 major sections)
3. **Roadmap** — Present overview and motivate the learner
4. **Teach** — One concept at a time with real terminology
5. **Check** — Verify understanding before moving on
6. **Wrap** — Summarize, vocabulary list, next steps

## Invoke

Use the `/educate-me` command:

```
/educate-me Kubernetes networking
/educate-me https://example.com/article
/educate-me ~/docs/specification.md
```

Or trigger naturally by saying things like:
- "Teach me about distributed consensus"
- "Walk me through this RFC"
- "I want to understand how TLS works"
