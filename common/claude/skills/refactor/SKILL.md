---
name: refactor
description: Scan for refactoring opportunities with value/effort ranking. Usage: /refactor <file-path>
---

Scan the provided file for refactoring opportunities. Don't report on bugs or style — focus on structural debt.

Look for: duplicated logic, god objects/functions, leaky abstractions, primitive obsession, tight coupling, missing seams for testing, conditionals that should be polymorphism, modules with multiple responsibilities, naming that obscures intent, hot spots that change frequently and break things.

For each opportunity, give me:

1. **What** — describe the smell concretely and quote the relevant lines/symbols
2. **Why it matters** — what concrete pain does it cause now or will cause soon? (slow tests, frequent bugs, onboarding friction, blocked features, etc.)
3. **Proposed refactor** — describe the target shape, not full code
4. **Effort estimate** — S / M / L / XL with a rough hours range and the riskiest part
5. **Blast radius** — how many files, tests, or callers are affected?
6. **Value vs effort verdict** — explicitly answer: is this worth doing now? Possible answers:
   - ✅ Worth it now (high value, manageable risk)
   - 🕐 Worth it eventually (good idea but not urgent)
   - ⚠️ Risky (real value but high blast radius — defer unless forced)
   - ❌ Not worth it (cost exceeds plausible value — leave it alone)
7. **Trigger to revisit** — what would change the verdict? (e.g. "if this file changes 3+ times in a quarter")

Be honest about ❌ verdicts. Most refactoring "opportunities" aren't worth the disruption. I'd rather you tell me to leave things alone than chase elegance.

At the end:

- Top 3 refactors ranked by value/effort
- Anything you'd advise me explicitly NOT to refactor and why
- One architectural-level observation about the codebase if relevant

Save your output:

- Save to `./.agent/reports/NNN-refactor-scan-[target-slug].md`
- Determine NNN by listing `./.agent/reports/` and using the next zero-padded 3-digit integer (start at 001 if empty or missing)
- `[target-slug]` is the kebab-case filename of the scanned file without extension
- Create `./.agent/reports/` if it doesn't exist
- At the top, include: target path scanned, date, count of opportunities by verdict (e.g. "2 ✅, 3 🕐, 1 ⚠️, 4 ❌")
