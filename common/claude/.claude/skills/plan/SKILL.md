---
name: plan
description: >
  Plan a new feature or extension for an EXISTING codebase as a read-only
  orchestrator. Analyzes coupling and hardcoding first, proposes integration
  options, then writes a phased plan with three test categories (non-regression,
  new-behavior, failure-mode). NOT for greenfield projects — use /new-project
  for that.
  Usage: /plan <feature-description>
---

I want to add the following to an existing project: $ARGUMENTS

You are a READ-ONLY orchestrator. Do not write application code. You WILL write test files (see "Test specifications") — that is the only code you produce in this skill.

Do the following, in this order:

1. **CLARIFY**: Ask me the 5–10 most important questions about the feature. Group them by: scope/goals, how it should interact with what already exists, technical constraints, success criteria, and anything explicitly OUT of scope. Wait for my answers before proceeding.

2. **ANALYZE THE EXISTING SYSTEM**: Before proposing anything, study the codebase and write up what you find. Specifically:
   - The interfaces/extension points a new feature of this kind must conform to
   - Where the current code is COUPLED or HARDCODED in ways that will break when extended (quote the file and line)
   - What must be refactored FIRST, before the new feature can be added cleanly
   - The existing test suite: what it covers, what it doesn't, how to run it
   - Risks and likely failure modes specific to this change

   Present this analysis to me and flag anything that changes the feature's feasibility.

3. **EXPLORE OPTIONS**: Propose 2–3 ways to integrate the feature, with explicit tradeoffs (invasiveness, refactor cost, risk to existing behavior). Don't recommend one yet. Wait for me to pick a direction.

4. **PROPOSE A PLAN**: After I pick a direction, write a phased plan as a standalone file.

   File location and naming:
   - Save to `./.agent/plans/` relative to the project root
   - Create `./.agent/plans/`, `./.agent/reports/`, `./.agent/decisions/` if missing
   - Filename: `NNN-[kebab-case-title].md`, zero-padded 3-digit NNN
   - Determine NNN from existing files in `./.agent/plans/`, next integer (001 if empty)

   Plan content requirements:
   - 4–6 phases, each shippable as a vertical slice. If a refactor must precede the feature, make it phase 1 with its own tests and non-regression anchors.
   - Each phase: 6–10 concrete tasks, numbered PHASE.TASK (e.g., 2.3)
   - Per phase: specific file paths to be created or modified
   - Per phase: key design decisions, open questions, risks
   - Per phase: a **## What NOT to touch** note listing files/modules to leave unchanged
   - Per phase: success criteria as the names of the tests that must pass
   - Per phase: a **## Verification** block — exact shell commands the coding agent must run and whose full output it must paste into its report
   - End with a "Handoff notes" section pointing to the relevant existing files

   Test specifications (you write these, I do not):
   - Derive the tests YOURSELF by analyzing the codebase. Do not ask me to write specs.
   - For each phase, write tests in three categories:
     - NON-REGRESSION: pin existing behavior with a hardcoded expected result (snapshot). These must pass BEFORE and AFTER all changes — they are the anchor proving you didn't break what already works.
     - NEW BEHAVIOR: the feature does what it should.
     - FAILURE MODES specific to this codebase — including the coupling/hardcoding you found in step 2 (e.g. units, calendars, locale, market/region assumptions).
   - For the NEW-behavior and FAILURE-MODE tests, work through this edge-case checklist
     explicitly: empty input, null/undefined, zero, negative numbers, max values,
     off-by-one boundaries, whitespace, unicode, very large input.
   - Write the ACTUAL test code into `tests/` before any implementation.
   - Every NEW-behavior and FAILURE-MODE test must FAIL before implementation, and must fail for the right reason (a real assertion, not an import or collection error). Run them once and confirm.
   - NON-REGRESSION tests should already PASS against current code — run them to confirm the anchor is valid before any change is made.
   - Every test must be grounded in something you found in the codebase. Do NOT invent generic tests, and do NOT test private methods or intermediate values.

   Test-craft rules (apply to every test you write):
   - Name each test for the scenario AND the expected outcome, so a failure message
     alone tells you what broke — e.g. `returns empty array when input is empty`,
     NOT `test empty input`.
   - One assertion per test where reasonable.
   - Add a comment only when the _why_ of a test isn't obvious from its name.
   - Mock external dependencies (DB, API, filesystem) at the boundary — never mock the
     unit under test.

   - List all test file paths in the plan's deliverables alongside the `.md` file.
   - In the plan, clearly label which tests are NON-REGRESSION (pass now, must keep passing) and which are NEW-BEHAVIOR / FAILURE-MODE (fail now, must pass when done), so the executing agent knows which is which.

5. **UPDATE CLAUDE.md**: If a CLAUDE.md exists, propose targeted additions only (new conventions, new verification commands, new modules) — do not rewrite it. If none exists, offer to create one. Show me the changes before applying.

Do not write any application code until I approve the plan.
