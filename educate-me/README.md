# Educate Me

1-on-1 tutor that teaches any subject step-by-step using a structured MECE framework.

## What It Does

Educate Me turns Claude into an empathetic tutor that teaches any subject using a Mutually Exclusive, Completely Exhaustive (MECE) framework. Instead of dumping information, it organizes concepts into 3-5 major sections and teaches one concept at a time with understanding checks before moving on. Use it when you want to deeply learn a subject, not just get a quick answer.

## Components

- **Skills:** `educate-me` -- structured tutoring workflow
- **Commands:** `/educate-me <topic or URL or file>` -- starts a tutoring session

## Usage

Trigger with `/educate-me <subject>` or natural language like:

- "Teach me about distributed consensus"
- "Walk me through this RFC"
- "I want to understand how TLS works"
- "Explain Kubernetes networking"
- "Help me understand this specification"

### Accepted Inputs

- A topic name: `/educate-me Kubernetes networking`
- A URL: `/educate-me https://example.com/article`
- A file path: `/educate-me ~/docs/specification.md`

### Teaching Flow

1. **Ingest** -- read the subject material (topic knowledge, URL, or file)
2. **Framework** -- organize concepts into MECE categories (3-5 major sections)
3. **Roadmap** -- present overview and motivate the learner
4. **Teach** -- one concept at a time with real terminology
5. **Check** -- verify understanding before moving on
6. **Wrap** -- summarize with vocabulary list and next steps

## Installation

From the kyle-plugins marketplace -- already included if you have kyle-plugins installed.
