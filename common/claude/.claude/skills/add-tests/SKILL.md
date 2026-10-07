---
name: add-tests
description: Add a safety-net test suite to EXISTING, already-working but untested code (characterization tests that pin current behavior). Use for legacy code before refactoring, or to create non-regression anchors. NOT for new features — those get their tests from the /plan or /new-project orchestrator. Usage: /add-tests <file-path>
---

Write a characterization test suite for the EXISTING file at the path provided. The code already runs; your job is to pin down what it currently does so it can be changed safely later. These tests describe current behavior and should PASS as written. (This is the opposite of the /plan orchestrator's fail-first tests — do not write failing tests here.) Don't write only happy-path tests — they're nearly worthless.

Before writing tests:

1. Read the code carefully. List the **public surface** (functions/methods/classes a caller would use).
2. For each public function, list:
   - **Happy path**: typical valid inputs
   - **Edge cases**: empty input, null/undefined, zero, negative numbers, max values, off-by-one boundaries, whitespace, unicode, very large input
   - **Error paths**: invalid input, missing dependencies, network/IO failure, permission denied, malformed data
   - **Integration boundaries**: external calls (DB, API, filesystem) that should be mocked or stubbed
   - **State / ordering**: if the function depends on prior state or call order, test that
3. Show me this catalog FIRST. Don't write any tests until I confirm the coverage plan.

Then write the tests:

- One assertion per test where reasonable. Name tests so a failure message tells you exactly what broke.
- For each test, the name should describe the scenario AND the expected outcome (e.g. `returns empty array when input is empty`, not `test empty input`).
- Include comments only when the _why_ of the test isn't obvious from the name.
- For mocked dependencies, mock at the boundary — don't mock the unit under test.
- Capture behavior AS IT IS, not as it "should" be. If current behavior looks wrong, do NOT write the test to assert the "correct" output — that would make the test fail and defeats the safety-net purpose. Instead, pin the actual current behavior and flag the suspected bug separately (see below).

At the end:

- Report coverage: which functions/branches are tested, which aren't.
- Flag anything you intentionally didn't test and why (e.g. "trivial getter", "would require integration test infrastructure I don't have access to").
- Flag any bugs you noticed in the code while writing tests — don't fix them, just list them. For each, note whether the safety-net test currently pins the buggy behavior (so a future fix will need to update that test) or whether you left it untested pending a decision.

Run the tests after writing. Show me the output. Every test should PASS (since they describe current behavior); if any fail, you've either mis-described the behavior or found a bug — say which. Don't claim done until the suite runs clean (or until failures are explained).

Save your output:

- Save a coverage report (NOT the test file itself — that goes in the actual project test directory) to `./.agent/reports/NNN-test-coverage-[target-slug].md`
- Determine NNN by listing `./.agent/reports/` and using the next zero-padded 3-digit integer (start at 001 if empty or missing)
- `[target-slug]` is the kebab-case filename of the tested file without extension
- Create `./.agent/reports/` if it doesn't exist
- The report should contain: target file tested, test file path created, coverage catalog (what's tested / what's not / why), test run output, bugs noticed during test writing
