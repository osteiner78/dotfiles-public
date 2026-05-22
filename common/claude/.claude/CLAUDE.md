# Claude Global Configuration

## Who I am

Oliver Steiner — computer enthusiast learning new technologies, not a professional developer. I work across a macOS workstation (arm64), a home server (garfield, running Docker), and Linux VMs (currently preferring Fedora + niri).

---

## Who I am learning-wise

I'm learning — explain non-obvious concepts briefly without being asked, but don't over-explain basics. Assume good faith curiosity, not expert background.

---

## Environment

- **Shell:** zsh
- **Editors:** nvim (preferred), VSCode
- **Terminal:** ghostty + tmux
- **AI tools:** Claude Code, opencode (opencode go subscription)
- **Node:** nvm (current: v22) — use **pnpm** as package manager
- **Python:** miniconda3 — use **conda install** when possible, pip inside the conda env as fallback
- **macOS packages:** homebrew
- **Default scripting language:** Python

---

## Skills

Custom slash commands available: `/debug`, `/code-review`, `/refactor`, `/test-generator`, `/new-project`, `/plan-to-task`, `/handoff`. **Invoke only when explicitly called — do not auto-trigger based on keywords.**

### The `.agent/` convention

Save structured output to `.agent/` relative to the project root (create dirs as needed):

- `plans/` — NNN-\*.md — implementation plans
- `reports/` — NNN-\*.md — debug logs, reviews, test coverage, phase reports
- `decisions/` — NNN-\*.md — architectural decision records
- `context/` — background files to read before starting work on a project

NNN is always a zero-padded 3-digit integer. Use this convention unless a project-level CLAUDE.md says otherwise.

---

## Coding style

- No comments by default — only when the WHY is genuinely non-obvious
- No half-finished implementations — if out of scope, say so explicitly

---

## Git

- Commit messages: cover both **what** changed and **why** — one concise sentence each
- Phased plan execution: `[phase-X.Y] short description`
- Always `--recurse-submodules`
- Never force-push to main/master; never amend published commits

---

## Behaviour

- Ask before destructive actions (deleting files/branches, `rm -rf`, force-push)
- No emojis unless asked; concise responses, no padding
- Only commit when explicitly asked
- Flag BSD vs GNU tool differences when writing cross-platform scripts
- Never put secrets, tokens, or credentials in code or config files — always use `.env` or environment variables

---

## Karpathy Rules

Behavioral guidelines to reduce common LLM coding mistakes. Merge with project-specific instructions as needed.

**Tradeoff:** These guidelines bias toward caution over speed. For trivial tasks, use judgment.

## 1. Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:

- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them - don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

## 2. Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

## 3. Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:

- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it - don't delete it.

When your changes create orphans:

- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: Every changed line should trace directly to the user's request.

## 4. Goal-Driven Execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals:

- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"

For multi-step tasks, state a brief plan:

```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```

Strong success criteria let you loop independently. Weak criteria ("make it work") require constant clarification.
