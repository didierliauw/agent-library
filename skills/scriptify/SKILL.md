---
name: scriptify
description: Analyze the current session for friction and turn it into project scripts plus permission allowlist entries. Use whenever the user types /scriptify, asks "what could we script here?", "can you speed this up / make this more robust?", "reduce the permission prompts", "cut token usage", or at the end of a work session asks how the workflow could be improved or what's worth automating next time — even if they don't say the word "script". Also relevant when the user wants to wrap up and capture lessons from the session, or complains about repeated approvals, noisy command output, a slow dev loop, or commands that keep hanging or failing the same way.
---

# Scriptify — turn session friction into scripts

You have just spent a session doing real work. That session is evidence: every
command you repeated, every output you grepped down to one line, every retry,
every permission prompt the user had to click is a cost that will recur in
every future session — unless it gets captured in a script once. This skill
mines the current conversation for that evidence and, with the user's
approval, converts it into small scripts, allowlist entries, and docs.

The economics: a script is written once, but the friction it removes is paid
on every future invocation, by every future session. Even a small win (200
saved output tokens, one avoided permission prompt) compounds. But a script
nobody needs is pure noise — restraint is part of the job.

## Platform adaptation

The mining, scripting, and reporting steps are agent-agnostic. Two artifacts
differ per host agent — resolve them once at the start and use the resolved
form everywhere this skill says "allowlist" or "instructions file":

| Concept | Claude Code | Copilot CLI | Other agents |
|---|---|---|---|
| Permission allowlist | `"Bash(scripts/<name>.sh *)"` in `permissions.allow` of `<project>/.claude/settings.json` | `--allow-tool 'shell(scripts/<name>.sh:*)'` at launch, or approve once in-session and persist for the folder (no committed per-project permissions file) | the platform's mechanism, if any |
| Instructions file | `CLAUDE.md` | `AGENTS.md` or `.github/copilot-instructions.md` | whichever the project already uses |

If the project already has one instructions file, extend it — don't create a
second. If the host agent has no persistent allowlist, the script and the
quiet-on-success wrapper still pay for themselves in tokens and robustness;
say "allowlist: not supported here" in the proposal instead of inventing one.

## Step 1: Mine the session

Re-read the conversation you are in and collect concrete evidence in these
categories. Cite the actual occurrences (what command, how many times, what it
cost) — proposals without evidence get rejected and deserve to be.

- **Repetition** — the same command or multi-step sequence ran ~3+ times
  (builds, test-then-filter, restart dances). One script, one name, one call.
- **Noise** — commands whose output you immediately filtered (`| tail`,
  `| grep`, reading 400 lines to find one), or that print hundreds of lines on
  *success*. Wrapper pattern: quiet on success (print the one-line summary),
  dump everything on failure. This is the single biggest token saver.
- **Robustness** — commands that failed and you fixed the same way each time:
  missing PATH exports, a service that must be up first, a port to check
  before starting, retries after a known transient error. Encode the fix so
  it can never be forgotten.
- **Hangs and speed** — invocations that stalled or could stall forever
  (daemons, network calls, builds). Wrap with a bounded timeout and a clear
  failure message. Cache results of slow reads that don't change mid-session.
- **Permission prompts** — shell commands the user had to approve repeatedly.
  Two remedies: (a) wrap the workflow in a script and allowlist the script
  (one rule covers every future variation); or (b) for a genuinely safe
  single command, propose a narrow direct rule. Use the platform's rule
  syntax from the table above.

Before proposing anything, check `scripts/` (and the project's instructions
file) in the current project — prefer extending an existing script over
creating a near-duplicate.

What does NOT qualify: one-off commands, exploration that won't recur,
anything whose script would just restate a single flag. If the honest answer
is "this session had no recurring friction", say exactly that and stop — an
empty result is a valid result.

If the friction is process-shaped rather than command-shaped (e.g. "always
check the port before invoking docker"), propose a note in the instructions
file or a skill instead of a script — same proposal format, different
artifact.

## Step 2: Propose — nothing is written before approval

Present a numbered list. For each proposal:

```
### 1. scripts/test.sh — quiet test runner
- Evidence: ran `./gradlew testDebugUnitTest` 7× this session; each success
  printed ~45 lines that were immediately discarded; 2 runs were pasted
  through `tail -2`.
- Does: runs the tests via run-bounded.sh (killed after 120 s of output
  silence — a healthy run streams constantly); on success prints only the
  totals line; on failure dumps the full output.
- Tokens: without script ~550/run (45 lines from this session, ~4 chars per
  token); with script ~15/run (one summary line) — **~97% less**, ≈ 3,700
  tokens saved over this session's 7 runs.
- Benefit: a wedge dies in ~2 min instead of stalling the session; one
  allowlist rule replaces a prompt per run.
- Allowlist: Bash(scripts/test.sh *)
```

(The allowlist line shows Claude Code syntax — substitute the host agent's
rule form from the Platform adaptation table.)

Derive the token numbers from the session, not from imagination: take the
actual output the friction produced (≈ 1 token per 4 characters, or ~12 per
typical line), multiply by how often it ran, and compare against what the
wrapper will print on success. Quote per-run cost, the percentage saved, and
the session total — the percentage is what makes a marginal proposal easy to
judge. These are estimates; round them and say so rather than faking
precision. For proposals whose win isn't output volume (permission prompts,
hang protection), say "tokens: neutral" and let the other benefit carry it.

Then ask the user which to apply (multi-select, include "none"). Do not write
any file, script, or settings change before they answer. If a proposal
touches anything destructive or shared (git push, deletes, deploys), say so
explicitly in the proposal — never bury a destructive operation inside a
script where the allowlist would silently authorize it forever.

## Step 3: Implement what was approved

For each approved proposal:

1. **Write the script** to `<project>/scripts/<name>.sh` and `chmod +x` it.
   Conventions (each exists for a reason):
   - `#!/usr/bin/env bash` and `set -euo pipefail` — fail loudly, not half-way.
   - Quiet on success, full dump on failure — the token win is the point.
     Capture output to a temp file; on success print one summary line; on
     failure `cat` the file and exit nonzero.
   - Bounded waits only — every loop has a max iteration count, every
     long-running call a watchdog. A script that can hang is worse than no
     script (it stalls whole sessions silently). Prefer a **liveness bound**
     over a static one: build tools stream output while they work, so "kill
     after N seconds of *silence*" catches a wedge in ~2 minutes while letting
     a healthy long build run to completion — a static "kill after 10 minutes"
     is simultaneously too slow on hangs and too tight on big builds. Keep a
     generous static cap only as a backstop.
   - Do not hand-roll the watchdog — copy `scripts/run-bounded.sh` from this
     skill's directory into the project's `scripts/` and call
     `scripts/run-bounded.sh --stall 120 --max 1800 -- <command>` from your
     wrapper. Hand-rolled attempts reliably hit two traps this helper already
     solves: GNU `timeout` does not exist on macOS (scripts die with exit 127
     on the machine they were written for), and background `sleep`-watchdogs
     leak a child that holds stdout open, silently blocking any *piped* caller
     for the full timeout even after success. The helper polls in the
     foreground (nothing to leak) and kills the whole process group. Wrap
     EVERY external invocation that can wedge — including ones inside guards
     (a `docker compose up -d` behind a port-check still hangs when the
     daemon is wedged).
   - Small and single-purpose — aim under ~50 lines; a reader must be able to
     see at a glance that the allowlisted script does only what it claims.
   - A short header comment: what it does, why it exists (one line of the
     evidence), example invocation.
2. **Allowlist it** using the host agent's mechanism (Platform adaptation
   table). Claude Code: read `<project>/.claude/settings.json` first and
   merge — never clobber other keys — then add `"Bash(scripts/<name>.sh *)"`
   to `permissions.allow` (create the file or keys if missing). Copilot CLI:
   there is no committed settings file; record the launch flag
   (`--allow-tool 'shell(scripts/<name>.sh:*)'`) in the instructions file so
   the user can persist the approval. Keep rules narrow: the script path
   form, not a broad command pattern.
3. **Document it** in the project's instructions file (CLAUDE.md, AGENTS.md,
   or `.github/copilot-instructions.md` — whichever exists), commands
   section: one line per script — what to call instead of what raw command.
   Remind that scripts are invoked directly (`scripts/foo.sh`), not via
   `bash scripts/foo.sh` — permission systems treat the wrapper form as a
   different command and prompt again.
4. **Verify it** — run each new script once, right now, and show the output.
   A syntax check (`bash -n`) is NOT verification — it happily passes a script
   whose core command doesn't exist on this machine. Where a script has
   branches (a skip-path guard, a failure dump), exercise the branch you can
   reach cheaply *and* eyeball the one you can't: the bugs that ship are in
   the path verification never touched. If a script can't be run safely
   (e.g. it deploys), run its dry-run/help path. An unverified script is a
   proposal, not a deliverable.

## Step 4: Report

Close with a short table: script → friction it removes → tokens without →
tokens with → % saved → verified (yes/how). Reuse the estimates from Step 2,
corrected by what verification actually printed — if the wrapper's real
success output was 3 lines, not 1, the table says so. End with one line of
totals: estimated tokens saved per future session at this session's usage
rate. If any proposal was rejected, don't relitigate it; note it once as
"skipped by user" so a future session doesn't re-propose it identically.
