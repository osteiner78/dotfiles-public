---
name: new-project
description: >
  Greenfield project scaffold — use when there is NO existing codebase yet.
  Asks clarifying questions, proposes architectures, writes a phased plan with
  fail-first tests, and generates a starter CLAUDE.md. NOT for adding features
  to existing code — use /plan for that.
  Usage: /new-project <project-description>
---

I want to build the following project: $ARGUMENTS

Before writing any code, do the following — in this order:

1. **CLARIFY**: Ask me the 5–10 most important questions you have. Group them by: scope/goals, users/UX, technical constraints, deployment, success criteria. Wait for my answers before proceeding.

2. **EXPLORE OPTIONS**: Once I've answered, propose 2–3 alternative architectures with explicit tradeoffs. Don't recommend one yet.

3. **PROPOSE A PLAN**: After I pick a direction, write a phased plan as a standalone file.

   You are acting as a READ-ONLY orchestrator in this step. Do not write application code.
   You WILL write test files (see "Test specifications" below) — that is the only code you produce here.

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
   - Per phase: define success criteria as the names of the tests that must pass (see below)
   - Per phase: a **## Verification** block — the exact shell commands the coding
     agent must run (test runner, type checker, linter, smoke test) and whose full
     output it must paste into its report
   - End the file with a "Handoff notes" section pointing to relevant files

   Test specifications (you write these, I do not):
   - Derive the tests YOURSELF from the architecture you proposed in step 2 and the
     plan you are writing. Do not ask me to write specs.
   - For each phase, identify: new behavior that must become true, and failure modes
     implied by the design (bad input, boundary conditions, integration seams).
   - Cover: happy path, error cases, integration points between components, and edge
     cases. For edge cases, work through this checklist explicitly: empty input,
     null/undefined, zero, negative numbers, max values, off-by-one boundaries,
     whitespace, unicode, very large input.
   - Write the ACTUAL test code (not descriptions) into `tests/` before any implementation.
   - Each test must FAIL before implementation — proving it tests something real.
     Run them once and confirm they fail for the right reason (a real assertion,
     not an import or collection error).
   - Do NOT invent tests for behavior the plan doesn't specify, and do NOT test private
     methods or intermediate values — test behavior and outputs only.

   Test-craft rules (apply to every test you write):
   - Name each test for the scenario AND the expected outcome, so a failure message
     alone tells you what broke — e.g. `returns empty array when input is empty`,
     NOT `test empty input`.
   - One assertion per test where reasonable.
   - Add a comment only when the _why_ of a test isn't obvious from its name.
   - Mock external dependencies (DB, API, filesystem) at the boundary — never mock the
     unit under test.

   - List the test file paths in the plan's deliverables alongside the `.md` file.
   - In the plan, label each test (or test group) as NEW-BEHAVIOR or FAILURE-MODE so the executing agent knows all tests should fail before implementation and can orient itself when reading the plan.

4. **SETUP CLAUDE.MD**: Generate a starter CLAUDE.md for the project containing:
   - Stack and key dependencies
   - Coding conventions
   - Verification requirements: a task is complete ONLY when its tests pass and the verification output is pasted into the report. Never mark a task done by inspection.
   - Tests are owned by the orchestrator, implementation by the coder. The coder may add tests but must not weaken or delete an orchestrator-written test to make it pass.
   - Destructive-action confirmation rules
   - Anything else you'd want a future Claude instance to know

Do not write any application code until I approve the plan and CLAUDE.md.
