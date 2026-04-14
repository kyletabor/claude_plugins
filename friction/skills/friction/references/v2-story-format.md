# V2 Friction Story Format

V2 stories are HTML documents published to piDocs. Kyle's comments on them are the deliverable — the story is the engagement mechanism that draws his reactions out.

## Voice & Structure

- Write TO Kyle in second person: "you were skiing", "you said"
- Chronological play-by-play with time markers ("Thursday", "Friday", "4:18 PM PT")
- ALL timestamps in Pacific Time — the Orange Pi runs UTC, always convert
- Conversational tone, like Claude talking directly to Kyle
- Kyle's verbatim quotes are the most important content — always include them
- Include Claude's side of conversations when Kyle asks or when it adds context
- Interpretation of problems/intent is fine. Editorial flourish is not.
- No fancy section headers ("The Gap Between Minds") — use time markers or plain labels
- Keep it short enough to read and comment on in one sitting
- End with a fault analysis / breakdown section

## Why V2 Works

The play-by-play invites Kyle's reaction. He naturally wants to correct, expand, and add context when someone tells HIM his own story. V1 felt finished and published — he couldn't engage with it.

## CSS Template (dark background, mandatory)

```css
body { background: #1a1a2e; color: #e0e0e0; font-family: 'Segoe UI', system-ui, sans-serif; max-width: 850px; margin: 0 auto; padding: 2rem; line-height: 1.7; }
h1 { color: #79c0ff; font-size: 1.5rem; }
h2 { color: #58a6ff; font-size: 1.2rem; margin-top: 2rem; }
.quote { border-left: 3px solid #f85149; padding-left: 1rem; color: #f0b860; font-style: italic; margin: 1rem 0; }
.breakdown { background: #16213e; border: 1px solid #30365a; border-radius: 10px; padding: 1.5rem; margin: 1.5rem 0; }
.time-marker { color: #58a6ff; font-weight: 600; }
```

## Publishing

- File path: `total-recall/friction-stories/XX-slug-v2.html`
- Publish via `treehouse_create`
- Give Kyle the link: `http://orangepi:3500/documents/{PIDOC_ID}`

## Reference Stories

| Story | piDoc ID | Comments |
|-------|----------|----------|
| #1 The Wipe Cycle | `f49f0eeb49952ee4` | 6 |
| #2 Upload Broken | `c77ea9a166eadcc7` | 6 |
| #7 The Forgetting Machine | `dd6e657c52f77c67` | 7 |
| #11 I Honestly Don't Know Where We're At | `68afcf96ba047d2d` | 7 |
