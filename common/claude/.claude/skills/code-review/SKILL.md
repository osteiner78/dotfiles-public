---
name: code-review
description: >
  Detailed code review covering correctness, security, design, and test
  integrity — at whatever scope you specify (file, phase, diff, directory).
  NOT structural debt scanning (duplication, coupling, god objects) — use
  /refactor for that.
  Usage: /code-review <target> — where target is a file path, a phase
  (e.g. "phase 2 of plan 003"), a git diff/range, a directory, or a
  description of the change to review.
---

Perform a detailed code review of the target I specify: $ARGUMENTS

First, determine the SCOPE of the target:

- A single file path → review that file.
- A phase, a plan reference, a git range/diff, or a directory → review the whole change set. Use `git diff` (against the phase's starting commit or the range I gave) to see exactly what changed across ALL touched files, and review them together.
- A free-text description → review the code that matches it; ask me to point you at the files or commits if it's ambiguous.

If you're unsure of the scope from my argument, ask one clarifying question before starting.

If a plan and report exist for this work (look in `./.agent/plans/` and `./.agent/reports/` or a matching NNN), read them first. Tests have already verified correctness in this workflow, so do NOT spend the review re-checking "does it work" — focus on what tests cannot catch: design, coupling, security, readability, and whether the change stayed in scope. If there is no plan (a standalone file review), just review the file directly.

For each issue found, classify it as:

- 🔴 Critical (bugs, security, data loss, breaking changes)
- 🟡 Important (performance, maintainability, test gaps, error handling)
- 🟢 Suggestion (style, readability, idiomatic improvements)

For each issue:

1. Quote the specific lines
2. Explain the problem concretely (not "this could be better")
3. Show the fix as a diff or code snippet
4. Rate your confidence: certain / likely / speculative

Be a skeptical senior reviewer. Don't just agree the code is fine — assume there ARE issues and find them. If you find nothing critical, say so explicitly. Don't manufacture issues to seem thorough.

Test integrity check (perform whenever a plan/report exists):

- Compare the current tests against the tests the orchestrator wrote in the plan.
- Flag as 🔴 Critical any orchestrator test that was weakened (assertion loosened or removed), deleted, commented out, or marked skip/xfail/ignore to make the suite pass. Making tests green by changing the tests defeats the entire verification model — call it out explicitly even if everything else is clean.
- Note (not necessarily critical) any new test the coder added, and whether it genuinely covers behavior or just pads coverage.

Scope-adherence check (when reviewing a phase/diff/change set):

- Cross-check the touched files against the plan's **## What NOT to touch** list and the files the phase said it would modify. Flag anything changed outside the declared scope.

At the end:

- List the top 3 things to fix first
- Flag any architectural concerns that go beyond this file
- Note anything that should be tested but isn't — phrase each as a concrete test that a follow-up `/add-tests` run or the next `/plan` cycle could implement (scenario + expected outcome), not just "needs more tests"

Save your output:

- Save to `./.agent/reports/NNN-code-review-[target-slug].md`
- Determine NNN by listing `./.agent/reports/` and using the next zero-padded 3-digit integer (start at 001 if empty or missing)
- `[target-slug]`: if the target is a single file, the kebab-case filename without extension (e.g. `user-service` for `UserService.ts`); otherwise a short kebab-case label for what was reviewed (e.g. `phase-2-003`, `auth-refactor`)
- Create `./.agent/reports/` if it doesn't exist
- At the top of the file, include: target path reviewed, date, summary verdict (clean / minor issues / significant issues / critical issues)
