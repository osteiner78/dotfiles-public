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

- `plans/` — NNN-*.md — implementation plans
- `reports/` — NNN-*.md — debug logs, reviews, test coverage, phase reports
- `decisions/` — NNN-*.md — architectural decision records
- `context/` — background files to read before starting work on a project

NNN is always a zero-padded 3-digit integer. Use this convention unless a project-level CLAUDE.md says otherwise.

---

## Coding style

- No comments by default — only when the WHY is genuinely non-obvious
- No unnecessary abstractions — don't design for hypothetical future requirements
- No error handling for impossible cases — only validate at system boundaries
- Prefer editing existing files over creating new ones
- No half-finished implementations — if out of scope, say so explicitly

---

## Git

- Commit messages: cover both **what** changed and **why** — one concise sentence each
- Phased plan execution: `[phase-X.Y] short description`
- Always `--recurse-submodules`
- Never force-push to main/master; never amend published commits

---

## Behaviour

- **If you're not sure, say so. Don't guess.**
- **Don't just agree. Push back if there are legitimate concerns.**
- **Before starting any non-trivial task, ask me clarifying questions.**
- Ask before destructive actions (deleting files/branches, `rm -rf`, force-push)
- Don't over-engineer — match scope to what was requested
- No emojis unless asked; concise responses, no padding
- Only commit when explicitly asked
- Flag BSD vs GNU tool differences when writing cross-platform scripts
- Never put secrets, tokens, or credentials in code or config files — always use `.env` or environment variables
