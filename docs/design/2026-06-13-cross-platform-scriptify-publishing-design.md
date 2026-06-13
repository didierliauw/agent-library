# Cross-platform publishing of the scriptify skill

**Date:** 2026-06-13
**Status:** Approved (design phase)
**Repo:** `agent-library` — public GitHub, MIT license

## Goal

Publish the `scriptify` skill as a distributable that works on at least
**Claude Code** and **GitHub Copilot CLI**.

The repo, `agent-library`, is a broader cross-platform **agent-customization
library**, not skills-only: the same plugin manifests can also carry agents,
hooks, MCP server configs, and slash commands (the `plugin.json` schema has
`agents`, `hooks`, and `mcpServers` fields alongside `skills`). scriptify is
the first component to ship; the layout below anticipates sibling `agents/`,
`hooks.json`, etc. being added later without restructuring.

## Background

`scriptify` mines a work session for friction (repeated commands, noisy
output, permission prompts, hangs) and converts it into project scripts plus
permission-allowlist entries. Its `SKILL.md` was already generalized to be
host-neutral: a Platform-adaptation table maps the permission allowlist and
instructions-file concepts to each host (Claude Code: `.claude/settings.json`
+ `CLAUDE.md`; Copilot CLI: `--allow-tool 'shell(...)'` + `AGENTS.md` /
`.github/copilot-instructions.md`). The skill depends on
`scripts/run-bounded.sh`, a portable liveness watchdog that must ship with it.

Both Claude Code and Copilot CLI honor the Agent Skills spec
(agentskills.io/specification): a `SKILL.md` with `name` + `description`
frontmatter. This means **one SKILL.md is the shared artifact across hosts** —
no per-host copies of skill content.

## Architecture

### Principle: one shared skills folder, thin per-host manifests

A single `skills/` directory is referenced from each host's manifest. Claude
Code and Copilot CLI both install it through their **native plugin
marketplaces** (different manifest files, same skills); hosts without a plugin
marketplace (Codex, Gemini, Cursor) get it via an `install.sh` that symlinks
the shared skills into their conventional skills directory. The skill content
lives once; only the small manifest files differ per host.

### Repo layout

```
agent-library/
  .claude-plugin/
    plugin.json            # Claude Code plugin manifest (name, version, desc, keywords)
    marketplace.json       # Claude marketplace registry; plugin entry, source "."
  .github/plugin/
    marketplace.json       # Copilot marketplace registry (canonical location)
  plugin.json              # Copilot plugin manifest at repo root; "skills": ["skills/"]
  .cursor-plugin/
    plugin.json            # Cursor manifest (no native marketplace; see below)
  skills/
    scriptify/
      SKILL.md             # the shared, host-neutral skill
      scripts/
        run-bounded.sh     # the watchdog dependency, ships with the skill
  install.sh               # fallback installer for hosts without a plugin marketplace
  README.md                # per-host install instructions
  LICENSE                  # MIT
  evals/
    scriptify/             # dev-only evals, relocated OUT of the skill folder
  docs/design/             # this design doc
```

`evals/` is moved out of `skills/scriptify/` so neither plugin packaging nor the
installer ships eval fixtures into users' skill dirs.

All four manifest entry points (`.claude-plugin/plugin.json`, root `plugin.json`,
and the two `marketplace.json` files) reference the **same** `skills/` directory.
Skill content is never duplicated.

### Distribution paths

Both primary hosts have a **native plugin marketplace** — this is the main
correction from the first draft of this spec.

**Claude Code — native plugin install:**
- `/plugin marketplace add didierliauw/agent-library`
- `/plugin install scriptify`
- Driven by `.claude-plugin/marketplace.json` (plugin entry, `source: "."`)
  and `.claude-plugin/plugin.json`. Claude Code discovers `skills/` relative to
  the plugin root.

**Copilot CLI — native plugin install:**
- `copilot plugin marketplace add didierliauw/agent-library`
- `copilot plugin install scriptify`
- Driven by `.github/plugin/marketplace.json` (canonical Copilot location; the
  `.claude-plugin/` location is documented as an accepted alternative but we use
  the canonical one to avoid ambiguity) and the **root-level `plugin.json`**,
  which must declare `"skills": ["skills/"]`. Copilot requires `plugin.json` at
  the plugin root, not inside `.claude-plugin/`.

**Codex, Gemini, Cursor — installer script (`install.sh`):**
These hosts have no Copilot-style plugin marketplace; they read skills from a
conventional directory. `install.sh` maps each to its skills dir and creates
per-skill symlinks. It also serves as a manual fallback for Claude/Copilot.

  | Host        | Target dir            | Source confidence            |
  |-------------|-----------------------|------------------------------|
  | Codex       | `~/.agents/skills`    | confirmed (shared convention)|
  | Gemini      | `~/.agents/skills`    | confirmed (shared convention)|
  | Cursor      | `~/.cursor/skills`    | **assumed — verify in impl** |
  | Claude Code | `~/.claude/skills`    | confirmed (fallback only)    |
  | Copilot CLI | `~/.copilot/skills`   | confirmed (fallback only)    |

  The implementation plan must verify each host's exact skills-directory path
  against current host documentation before hardcoding it; the Cursor path in
  particular is an assumption. Link style is per-skill for all (one symlink per
  `skills/<name>` into the target), which is the safe default.

### Per-host behavior of the skill itself

No change required. When `scriptify` *runs* on a given host, its existing
Platform-adaptation table makes it emit the correct allowlist syntax and
write to the correct instructions file. Installing it on Copilot makes it
behave correctly on Copilot.

### install.sh robustness requirements

The installer eats its own dog food (scriptify's own rules):
- `#!/usr/bin/env bash`, `set -euo pipefail`.
- Idempotent symlinks (re-running is safe; replaces stale links).
- `--dry-run` prints the symlinks it would create without making them.
- `--uninstall <host>` removes the links it created.
- Prompts for host if not given an argument; accepts host id as `$1`.
- macOS-compatible (no GNU-only flags).

## Testing / verification

- **Manifest validity:** all `plugin.json` / `marketplace.json` files parse as
  JSON and carry the required fields for their host (Claude: name/version;
  Copilot: name + `skills` array). Verifiable on this machine.
- **Claude Code:** install the plugin locally from the repo, confirm
  `/scriptify` triggers and `scripts/run-bounded.sh` runs. Verifiable on this
  machine.
- **Copilot CLI:** `copilot` is not installed on this machine, so the native
  `copilot plugin marketplace add` / `copilot plugin install` flow and a live
  skill trigger remain **unverified** until run on a machine with Copilot. We
  verify what we can statically: root `plugin.json` parses and its `skills`
  path resolves; `.github/plugin/marketplace.json` parses and its plugin
  `source` resolves. README and final report state the live gap honestly.
- **install.sh:** exercise `--dry-run`, a real install into a throwaway `HOME`,
  and `--uninstall`.

## Out of scope

- Publishing to any central registry beyond a public GitHub repo.
- Automated CI for the eval suite (can come later).
- Additional components (other skills like graphify, plus agents, hooks, MCP
  configs, commands) — the layout and manifests support them, but only
  scriptify ships now.

## Open questions

None outstanding. Repo name `agent-library`, public GitHub, MIT license all
confirmed.
