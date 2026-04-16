# PR Review Command

Review the current branch's PR changes using the team's established review standards, derived from ~4,300 review comments.

## Instructions

### Step 1: Gather the Diff

Get the full diff of the current branch against main:

```bash
git diff main...HEAD
```

Also check the commit log for context:

```bash
git log --oneline main..HEAD
```

If there are unstaged changes, also review those with `git diff`.

### Step 2: Review Against the Knowledge Base

Read the review knowledge base at `.claude/review-knowledge-base.md` to understand the team's review standards.

Apply every category from the knowledge base systematically to the diff. For each file changed, check against ALL applicable rules.

### Step 3: Output Format

Produce a review structured as follows:

**Summary**: One sentence on what the PR does.

**Issues** (must fix):
List concrete problems, each with:
- File and line reference
- What's wrong
- What to do instead
- Which reviewer pattern it violates (for traceability)

**Suggestions** (nice to have):
Same format as issues but lower priority.

**Looks Good**:
Brief note on what's done well (keep short).

### Review Priorities (in order)

1. Security and auth (missing authz, data exposure)
2. Error handling (silent failures, missing wraps, interpolated values)
3. Architecture (wrong file placement, wrong service, export visibility)
4. API design (naming, request/response patterns, idempotency)
5. Frontend patterns (component choice, styling, keys, client vs server)
6. Naming and conventions
7. Simplification opportunities
8. Copy and UX

### Important

- Only flag real issues. Don't invent problems that aren't in the diff.
- Reference specific lines and files.
- Don't suggest changes to code that wasn't modified in the PR.
- Be direct. No filler.