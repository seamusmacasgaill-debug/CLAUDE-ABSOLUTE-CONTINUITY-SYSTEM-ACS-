# ACS v2 — Recommendations
# Based on extended use in webbuilder project (Sessions 1–28, 2026-02 to 2026-03)
# Authored: Claude Sonnet 4.6 + James MacAskill, 2026-03-18

---

## What Held Up

The three mechanisms that proved most valuable in practice:

1. **Commit hash requirement** — the single most reliable enforcement mechanism. "No hash = not complete" is unchallengeable. Every other rule can be argued around; this one cannot.
2. **Credit horizon check** — the explicit "safe to start: YES/NO" gate before MEDIUM/LARGE tasks. Prevents the most common failure mode (session ends mid-task, undocumented partial state).
3. **Structured termination** — knowing there is a defined shutdown sequence means sessions end cleanly even under time pressure, rather than trailing off.

---

## What Needs Changing

### 1. Merge MUST_READ + CHECKPOINT into a single Document of Record

**Current:** Three documents (MUST_READ.md, CHECKPOINT.md, STATE.md) updated at different times for different purposes.

**Problem:** Too many places to update. When sessions are long or end abruptly, some documents get updated and others don't. The inconsistency between documents is itself a source of confusion for the next session.

**Recommendation:** Introduce a single **Document of Record** — one file that holds all live session state:
- Current sprint task statuses (with commit hashes) ← from STATE.md
- Immediate next action ← from MUST_READ.md
- Known issues and open questions ← new
- Production/repo state ← new
- Checkpoint protocol reference ← from CHECKPOINT.md

STATE.md becomes the verified completions archive (historical). MUST_READ.md becomes the startup brief generated from the Document of Record. CHECKPOINT.md is retired — its function moves into the Document of Record updated in real time.

In the webbuilder project this is implemented as `SESSION-GATE.md`. It works well. The key rule: **the closing trigger confirms, it does not catch up.** By the time the closing trigger runs, the Document of Record should already be accurate because it was updated after every task.

---

### 2. Add a `/checkpoint` Claude Code Skill

**Current:** ACS describes CHECKPOINT.md update as a manual step after every ATU. In Claude Code, this relies on the model remembering to do it.

**Recommendation:** Add a `/checkpoint` skill to the Claude Code template set. When invoked:
1. Updates the Document of Record with current task statuses
2. Commits and pushes the docs repo
3. Reports what was saved

This is especially important for the auto-compact scenario (see below).

**Skill file location:** `.claude/skills/checkpoint/SKILL.md` in the project.

---

### 3. Auto-Compact Awareness

**Current:** ACS v1 mentions "context window exhaustion" as a failure mode but gives no concrete mechanism beyond "execute termination protocol immediately."

**Problem:** Claude Code shows a visual countdown (10% / 5% / 3% remaining) but there is no automatic trigger. By the time the user notices, there may not be enough context to complete the full termination protocol.

**Recommendation:**
- Add explicit instruction in CLAUDE.md / startup brief: "When auto-compact countdown is visible in the CC interface, run `/checkpoint` immediately — do not wait for task completion."
- The per-task checkpoint protocol (commit after every completed task) means auto-compact hitting mid-task is recoverable from the last checkpoint commit rather than from scratch.
- The `/checkpoint` skill (above) is the mechanism. Compact can then be run safely — the Document of Record is the recovery point.

---

### 4. Task Sizing in the Document of Record

**Current:** ACS defines task sizes (MICRO/SMALL/MEDIUM/LARGE) and the credit horizon check, but the sizes live in MUST_READ.md and the check is a behavioural rule.

**Recommendation:** Add a `Size` column to the task table in the Document of Record alongside the `Commit` column. This makes sizing visible at a glance and makes the credit horizon check easier to apply — you can see at session open which tasks are MEDIUM/LARGE and plan accordingly.

---

### 5. Clarify "Do Not Retrofit" — Retrograde Audit Is Valuable

**Current:** ACS v1 says "do not retrofit onto existing projects with undocumented history" and provides a brief retrograde survey approach.

**Problem:** The retrograde survey is described briefly and somewhat dismissively. In practice, a structured audit before major phase transitions is one of the most valuable things you can do — it surfaces undocumented decisions, stub files claimed as complete, and env var drift before you build on top of them.

**Recommendation:** Elevate the retrograde audit to a first-class ACS tool. Rename it **Pre-Phase Audit** and give it its own protocol:
- Run at the start of any major new phase (billing integration, hosting, etc.)
- Scope: DB schema vs docs, API routes vs sprint claims, env vars vs deploy config, git history for undocumented commits
- Output: a single `PHASE-N-AUDIT.md` that Sprint N can rely on as ground truth
- This is distinct from the ongoing STATE.md — it is a point-in-time snapshot, not maintained after the phase begins

---

### 6. Memory System for Claude Code Projects

**Current:** ACS has MEMORY.md for architectural decisions and problems solved. For Claude Code specifically, there is a built-in auto-memory system (`~/.claude/projects/[project]/memory/`) that persists across sessions independently of the project repo.

**Recommendation:** For Claude Code projects, split MEMORY.md into two:
- **Repo MEMORY.md** (as now) — architectural decisions, problems solved, external dependencies. Committed to git, readable by anyone.
- **Claude Code memory files** — feedback rules, confirmed infrastructure facts, cross-session project state. Written to `~/.claude/projects/[project]/memory/` using typed files (user/feedback/project/reference). These are loaded automatically at every session start without consuming context.

The typed memory approach ensures that feedback like "never use registry reference for local packages" or "alchemistnet.com redirect is live — do not list as open issue" survives session boundaries without needing to be in the Document of Record.

---

### 7. `verify_state.py` — Retain and Extend

The startup verification script is ACS's most underrated mechanism. Retain it. Two extensions worth adding:

- **Env var check:** cross-reference env vars in deploy config against `.env.example`. Flag any var in deploy that is missing from example, and any Stripe/API key not in GitHub Secrets manifest. This catches the "silently wiped env var" failure mode.
- **Document of Record freshness check:** warn if the Document of Record has not been committed in more than N hours (configurable). Stale docs are a leading indicator of session discipline breakdown.

---

## Summary of Recommended Changes for v2

| Change | Priority | Effort |
|--------|----------|--------|
| Merge MUST_READ + CHECKPOINT → Document of Record | High | Medium |
| Add `/checkpoint` skill to Claude Code template | High | Low |
| Add auto-compact guidance to CLAUDE.md template | High | Low |
| Add `Size` column to task table | Medium | Low |
| Elevate retrograde audit to Pre-Phase Audit protocol | Medium | Medium |
| Split MEMORY.md → repo + Claude Code memory | Medium | Low |
| Extend `verify_state.py` with env var + doc freshness checks | Low | Medium |

---

## What Does Not Need Changing

- **The one rule** ("no VERIFIED without a commit hash") — keep exactly as written
- **ATU structure** — the five-field format (Intent / Actions / Verify / Commit / Update) is correct and sufficient
- **Emergency termination priority order** — Priority 1 commit, Priority 2 CHECKPOINT, Priority 3 MUST_READ flag is the right order
- **"New projects only" principle** — correct. The Pre-Phase Audit (above) is the right answer for existing projects at phase transitions, not a full retrofit
- **CLAUDE.md under 100 lines rule** — critical. Every line is consumed on every session open. Keep it ruthlessly short.
