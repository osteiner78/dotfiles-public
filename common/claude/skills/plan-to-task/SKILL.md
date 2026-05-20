---
name: plan-to-task
description: Convert an implementation plan file into self-contained per-task prompts for a stateless coding agent. Usage: /plan-to-task <plan-file-path>
---

Convert the implementation plan at the provided path into a series of per-task prompts suitable for a coding assistant that has NO persistent project context between turns.

For each task in the plan, produce one self-contained prompt with the following structure:

---

### Task [phase.task-number]: [short title]

**Context** (1–3 sentences): what this task is part of, and why it matters. Include the minimum context a fresh assistant needs to understand the goal — don't assume it has read prior tasks.
**Files involved**: list of paths to read or modify, with one-line descriptions of each. If a file should be created, mark it as NEW.
**Goal**: one sentence stating the outcome.
**Implementation requirements**: bullet points covering specific behaviors, edge cases, libraries, and patterns to follow. Reference existing patterns in the codebase where applicable (e.g. "follow the pattern in services/AuthService.ts").
**Acceptance criteria**: specific testable outcomes. Include example inputs/outputs where useful. The assistant should know exactly how to verify it's done.
**Out of scope**: what NOT to do in this task (refactors, unrelated improvements, scope creep).
**Dependencies**: which prior tasks must be complete first. If none, say "None."

---

Guidelines:

- Include the _why_ behind requirements where non-obvious. Coding assistants make better decisions with rationale, not just imperatives.
- Don't strip explanations to save tokens. Clarity beats brevity for this use case.
- Each prompt must stand alone — assume the executor has not seen the plan or other prompts.
- If a task is too large to fit cleanly in one prompt, split it and note the split at the top.
- At the very end, produce a "task index" listing all tasks in execution order with a one-line description of each.

Save your output:

- Save to `./.agent/plans/NNN-tasks-from-[plan-slug].md`
- Determine NNN by listing `./.agent/plans/` and using the next zero-padded 3-digit integer (start at 001 if empty or missing)
- `[plan-slug]` is the source plan's filename without the NNN prefix or extension (e.g. for `001-user-auth.md`, use `user-auth`)
- Create `./.agent/plans/` if it doesn't exist
- At the top, include: source plan path, total task count, estimated execution order
