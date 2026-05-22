---
name: new-project
description: New project scaffold with phased implementation plan. Usage: /new-project <project-description>
---

I want to build the following project: $ARGUMENTS

Before writing any code, do the following — in this order:

1. **CLARIFY**: Ask me the 5–10 most important questions you have. Group them by: scope/goals, users/UX, technical constraints, deployment, success criteria. Wait for my answers before proceeding.

2. **EXPLORE OPTIONS**: Once I've answered, propose 2–3 alternative architectures with explicit tradeoffs. Don't recommend one yet.

3. **PROPOSE A PLAN**: After I pick a direction, write a phased plan as a standalone file.

   File location and naming:
   - Save to `./.agent/plans/` relative to the project root
   - If the directory doesn't exist, create it (along with `./.agent/reports/` and `./.agent/decisions/`)
   - Filename format: `NNN-[kebab-case-title].md` where NNN is a zero-padded 3-digit number
   - Determine NNN by listing existing files in `./.agent/plans/` and using the next integer (start at 001 if empty)
   - Example: `./.agent/plans/001-user-authentication.md`

   Plan content requirements:
   - 4–6 phases, each shippable as a vertical slice
   - Each phase: 6–10 concrete tasks, numbered as PHASE.TASK (e.g., 2.3)
   - Per phase: list specific file paths to be created or modified
   - Per phase: flag key design decisions, open questions, risks
   - Per phase: define success criteria (specific test cases or measurable outcomes)
   - End the file with a "Handoff notes" section pointing to relevant files in the codebase

4. **SETUP CLAUDE.MD**: Generate a starter CLAUDE.md for the project containing:
   - Stack and key dependencies
   - Coding conventions
   - Verification requirements (don't mark tasks complete without test results)
   - Destructive-action confirmation rules
   - Anything else you'd want a future Claude instance to know

Do not write any application code until I approve the plan and CLAUDE.md.
