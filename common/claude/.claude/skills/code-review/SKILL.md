---
name: code-review
description: Detailed code review with severity classification. Usage: /code-review <file-path>
---

Perform a detailed code review of the provided file.

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

At the end:

- List the top 3 things to fix first
- Flag any architectural concerns that go beyond this file
- Note anything that should be tested but isn't

Save your output:

- Save to `./.agent/reports/NNN-code-review-[target-slug].md`
- Determine NNN by listing `./.agent/reports/` and using the next zero-padded 3-digit integer (start at 001 if empty or missing)
- `[target-slug]` is the kebab-case filename of the reviewed file without extension (e.g. `user-service` for `UserService.ts`)
- Create `./.agent/reports/` if it doesn't exist
- At the top of the file, include: target path reviewed, date, summary verdict (clean / minor issues / significant issues / critical issues)
