# Task Bead Description Template

Use this format when creating task beads:

```markdown
## Goal

[Single sentence - what this task accomplishes]

## Acceptance Criteria

- [ ] [Verifiable outcome 1]
- [ ] [Verifiable outcome 2]
- [ ] [Verifiable outcome 3]

## Steps

### 1. [Step name] (~X min)

[Exact instructions]

```language
// Complete code to write
```

### 2. [Step name] (~X min)

[Exact instructions]

```language
// More code
```

### 3. Verify (~1 min)

```bash
[command to verify]
```

Expected: [what success looks like]

### 4. Commit

```bash
git add [files]
git commit -m "[message]"
```

## Context

- **Reference**: `path/to/similar/file` - follow this pattern
- **Depends on**: [what must exist first]
- **Watch out for**: [common pitfalls]
```

## TDD Pattern Example

```markdown
## Goal

Add email validation to user registration

## Acceptance Criteria

- [ ] Invalid emails rejected with clear error message
- [ ] Valid emails accepted
- [ ] Edge cases handled (empty, no @, no domain)

## Steps

### 1. Write failing test (~3 min)

Create `tests/validation/email.test.ts`:

```typescript
import { validateEmail } from '../../src/validation/email'

describe('validateEmail', () => {
  it('rejects empty string', () => {
    expect(validateEmail('')).toEqual({ valid: false, error: 'Email required' })
  })

  it('rejects missing @', () => {
    expect(validateEmail('test.com')).toEqual({ valid: false, error: 'Invalid email format' })
  })

  it('accepts valid email', () => {
    expect(validateEmail('user@example.com')).toEqual({ valid: true })
  })
})
```

### 2. Verify test fails (~1 min)

```bash
npm test -- email.test.ts
```

Expected: Test fails with "validateEmail is not defined"

### 3. Implement (~5 min)

Create `src/validation/email.ts`:

```typescript
interface ValidationResult {
  valid: boolean
  error?: string
}

export function validateEmail(email: string): ValidationResult {
  if (!email) {
    return { valid: false, error: 'Email required' }
  }

  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/
  if (!emailRegex.test(email)) {
    return { valid: false, error: 'Invalid email format' }
  }

  return { valid: true }
}
```

### 4. Verify test passes (~1 min)

```bash
npm test -- email.test.ts
```

Expected: All tests pass

### 5. Commit

```bash
git add tests/validation/email.test.ts src/validation/email.ts
git commit -m "Add email validation with tests"
```

## Context

- **Reference**: `src/validation/phone.ts` - follow same pattern
- **Depends on**: None (standalone utility)
- **Watch out for**: Don't over-engineer regex, simple validation is fine
```

## Quality Checklist

Each task must have:

- [ ] Verb-first title ("Add X", "Fix Y", "Create Z")
- [ ] 3+ verifiable acceptance criteria
- [ ] Complete code in steps (no placeholders)
- [ ] Time estimates per step (2-5 min each)
- [ ] Verification step with expected output
- [ ] Commit step with specific files and message
- [ ] Context section with references and gotchas
