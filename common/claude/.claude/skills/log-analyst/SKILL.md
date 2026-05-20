---
name: log-analyst
description: >
  Analyze system logs and report on errors, warnings, and health issues.
  Use when asked to check logs, audit system health, investigate errors,
  or diagnose misbehaving services — on any Linux or macOS machine.
---

# Log Analyst

Perform a structured analysis of system logs. Surface real problems, tier them
by severity, explain what they mean, and propose concrete fixes. Be direct —
don't soft-pedal real problems, but don't cry wolf over normal noise either.

## Step 1 — Determine the window

Default: **24 hours**. Use whatever the user specified ("last 3 days" = 72h, etc.).

Also create the report output directory if it doesn't exist:
```bash
mkdir -p ~/temp
```

## Step 2 — Run the collection script

```bash
bash ~/.claude/skills/log-analyst/scripts/collect_logs.sh <HOURS>
```

The script auto-detects Linux vs macOS and collects from all relevant sources:
journalctl, dmesg, auth logs, Docker containers, disk usage, memory, and
`/var/log` files. All output is pre-filtered to errors/warnings and deduplicated
(each line prefixed with a repeat count) to keep token usage manageable.

**User-requested overrides** — honor these without pushback:
- "show full docker logs for X" → `docker logs --since <HOURS>h X 2>&1`
- "check the last 7 days" → re-run the script with 168
- "show context around that error" → `docker logs --since <HOURS>h X 2>&1 | grep -A 10 -B 5 "<snippet>"`
- "read /var/log/syslog directly" → do it

## Step 3 — Analyse and tier

| Tier | Label | Criteria |
|------|-------|----------|
| 1 | 🔴 Critical | Data loss risk, crash loops, OOM kills, disk ≥ 90%, kernel panic, active intrusion |
| 2 | 🟠 High | Service down/degraded, repeated container restarts, disk ≥ 80%, brute-force auth attempts, failed mounts |
| 3 | 🟡 Medium | Non-fatal repeated errors, performance warnings, config issues not yet breaking things |
| 4 | 🟢 Low | One-off warnings, deprecation notices, harmless known noise |

The repeat count from the script matters — 47 identical errors is more serious than
one, even within the same tier.

**Common noise to skip or mention only briefly:**
- `systemd-resolved` DNSSEC warnings on home/office networks
- NetworkManager activation failures during brief disconnects
- Docker `layer already exists` during pulls
- Linuxserver.io container startup banners

## Step 4 — Propose solutions

- **Simple fix** (1–2 commands): write inline as a code block
- **Complex fix** (multi-step, risky, or ordering-sensitive): write a full plan:

```
### Implementation Plan: <issue name>
**Goal**: <one sentence>
**Risk**: <what could go wrong>
**Estimated time**: <rough guess>

Steps:
1. ...
2. ...

Rollback:
- ...
```

If there are multiple complex issues, ask which one the user wants a plan for
rather than writing unsolicited plans for everything.

## Step 5 — Offer to dig deeper

After your summary, if specific errors need more context:

> "sonarr logged 23× `DB is locked`. Want me to pull the surrounding lines
> to see what triggered it?"

Fetch additional context only when the user agrees.

## Step 6 — Write report to disk

Save the full report (all tiers, all findings, any implementation plans) to:

```
~/temp/log-report-<YYYYMMDD-HHMM>.md
```

Tell the user the full path at the end of your response.

## Output format

```
## System Health Report — <date, window>

### Summary
<2–3 sentence overall assessment>

### 🔴 Critical
<findings, or "None">

### 🟠 High
<findings, or "None">

### 🟡 Medium
<findings, or "None">

### 🟢 Low / Informational
<findings, or "None">

### Clean
<services/containers with no issues>

---
Report saved to: ~/temp/log-report-YYYYMMDD-HHMM.md
```
