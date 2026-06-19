---
name: debug
description: >
  Methodical hypothesis-driven debugging for a SPECIFIC reported bug.
  Reproduces the bug as a failing regression test before fixing.
  NOT for general code quality review — use /code-review for that.
  Usage: /debug <bug-description>
---

I'm stuck on a bug. Help me debug it methodically — no guessing, no shotgun fixes.

Recent commits (for context):
!`git log --oneline -10`

Current branch status:
!`git status --short`

The bug: $ARGUMENTS

Work through this in stages — don't skip ahead:

1. **CLARIFY**: Ask me any questions you need before forming hypotheses. Don't speculate yet. If you need to see more code, more logs, or to run a command, ask.

2. **HYPOTHESES**: List the 3–5 most likely root causes, ranked by probability. For each:
   - What would cause this exact symptom
   - Why this hypothesis specifically (cite the code/logs)
   - A cheap test that would confirm or rule it out
   - Confidence: high / medium / low / wild-guess

3. **TEST**: Walk me through the cheapest test first. If you can run it yourself (read a file, grep, run a command), do it. If I need to run it, give me the exact command and tell me what output would confirm vs. rule out.

4. **ITERATE**: Based on test results, either narrow to the actual cause or update the hypothesis list. Don't propose a fix until we've confirmed the cause.

5. **REPRODUCE AS A TEST**: Once the cause is confirmed, write a regression test that reproduces the bug — it should FAIL against the current (broken) code, and fail for the reason matching your confirmed cause (not an unrelated error). Show me it failing. This both proves the diagnosis and becomes a permanent guard against the bug returning. (If the bug genuinely can't be expressed as an automated test — e.g. it's environmental or UI-visual — say so and explain why, rather than skipping this step silently.)

6. **FIX**: Propose the minimum fix. Apply it, then run the regression test from step 5 and confirm it now passes, AND run the surrounding existing tests to confirm the fix didn't break anything else. Show the output. Separately note any related issues you noticed that we should address (but NOT in this fix — keep scope tight; route them to a follow-up).

Rules:

- Do NOT suggest "try restarting" or "check the logs" without specifying what to look for.
- If two hypotheses are equally likely, say so — don't pretend confidence you don't have.
- If your best hypothesis turns out wrong, say so explicitly and revise. Don't quietly switch theories.
- Symptoms can lie. Verify the bug is actually what I described before deep-diving.
- The regression test is owned by this debug session the same way orchestrator tests are owned by the plan: once it passes, do not weaken or delete it to make other things green.

Save your output:

- Once the bug is resolved (or we hit a stopping point), save a debug log to `./.agent/reports/NNN-debug-[bug-slug].md`
- Determine NNN by listing `./.agent/reports/` and using the next zero-padded 3-digit integer (start at 001 if empty or missing)
- `[bug-slug]` is a 3–5 word kebab-case summary of the bug (e.g. `auth-token-expiry-loop`)
- Create `./.agent/reports/` if it doesn't exist
- The log should contain: symptom described, hypotheses considered (with confidence), tests run and results, root cause identified, the regression test added (path + what it asserts), fix applied, post-fix test output, related issues noted for follow-up
- If we stopped without resolution, save anyway with status "unresolved" and the current state of investigation

After saving, remind me in one line that the debug log is the durable record and I can clear context before moving to the next task.