---
name: handoff
description: Hand off a written implementation plan to an agent for execution, phase by phase. Usage: /handoff <plan-file-path>
---

You are implementing the plan at the provided path. The plan was produced by a separate planning model after detailed clarification with the user — treat it as authoritative.

BEFORE writing any code:

1. Read the entire plan end-to-end.
2. Read CLAUDE.md (or equivalent project conventions file) if present.
3. Spot-check 1–2 referenced files to confirm you understand the existing patterns.
4. List anything that is ambiguous, missing, internally inconsistent, or technically infeasible. Be specific — quote the plan line and explain why it's a problem.
5. If you found issues in (4), STOP and wait for me to clarify. Do not invent answers.
6. If the plan is clear and consistent, write a 1-paragraph status update to `./.agent/reports/NNN-phase-N-start.md` confirming your understanding of the scope and any pre-work observations. Use the same NNN as the plan file (e.g., plan `001-foo.md` → report `001-phase-1-start.md`). Then proceed.

Execution rules:

- Follow the plan's phasing. Complete one phase before starting the next.
- Match existing codebase conventions (naming, structure, error handling, testing style). When in doubt, look at neighboring code rather than applying generic best practices.
- Do NOT refactor code outside the plan's scope, even if you see things you'd improve. Note them in a follow-ups list at the end instead.
- Do NOT add dependencies the plan didn't specify without asking first.
- For destructive operations (delete files, drop tables, force push, rm -rf), ASK before doing them.
- Commit after each completed task with a message in the format: `[phase-X.Y] short description` (e.g., `[phase-2.3] add user auth middleware`). This lets the user track progress via `git log` and revert granularly if needed.

Verification rules:

- After each task, run the relevant tests. If there are no tests for the changed area, write them first.
- Do not mark a task complete unless tests pass and you can show the output.
- If a test fails and the fix isn't obvious in <2 attempts, STOP and explain what's wrong rather than guessing.

When you're done with a phase, write a report to `./.agent/reports/NNN-phase-N-end.md` containing:

- What you built (1–2 sentences per task)
- Test results (include actual output, not just "passed")
- Any deviations from the plan, with reasoning
- Any follow-ups or noted-but-not-done items
- Confidence rating: certain / likely-good / needs-review

Then STOP and wait for user review before starting the next phase.
