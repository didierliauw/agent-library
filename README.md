# agent-library

Cross-platform agent customizations by Didier Liauw. One repo, one set of
skills, installable on multiple AI coding agents. Currently ships:

- **scriptify** — analyze a work session for friction (repeated commands, noisy
  output, permission prompts, hangs) and turn it into project scripts plus
  permission-allowlist entries. Invoke with `/scriptify` (or just ask
  "what could we script here?").

## Install

### Claude Code (native plugin marketplace)

```
/plugin marketplace add https://github.com/didierliauw/agent-library
/plugin install agent-library
```

Then use `/scriptify` in any project.

> Use the full HTTPS URL as shown. The `didierliauw/agent-library` shorthand
> also works, but Claude Code resolves it over SSH, which fails with a host-key
> error if you don't have SSH access to GitHub set up. The HTTPS URL needs no
> SSH configuration.

### GitHub Copilot CLI (native plugin marketplace)

```
copilot plugin marketplace add didierliauw/agent-library
copilot plugin install agent-library
```

> **Note:** The Copilot install flow above follows GitHub's documented plugin
> marketplace commands but has not been run end-to-end by the author (no
> Copilot CLI on the authoring machine). If a command differs in your version,
> see `copilot plugin --help`. If the shorthand errors with an SSH host-key
> message, use the full URL instead:
> `copilot plugin marketplace add https://github.com/didierliauw/agent-library`.
> Please open an issue if you hit a mismatch.

### Codex, Gemini, Cursor (installer script)

These agents read skills from a conventional directory rather than a plugin
marketplace. Clone the repo and run the installer for your host:

```
git clone https://github.com/didierliauw/agent-library
cd agent-library
./install.sh cursor      # or: codex | gemini
```

`./install.sh <host> --dry-run` previews the symlinks; `./install.sh --uninstall <host>` removes them. `claude` and `copilot` are also accepted as a manual fallback if you prefer symlinks over the native marketplace.

| Host | Skills directory |
|------|------------------|
| Codex / Gemini | `~/.agents/skills` |
| Cursor | `~/.cursor/skills` |
| Claude Code | `~/.claude/skills` (prefer the plugin marketplace) |
| Copilot CLI | `~/.copilot/skills` (prefer the plugin marketplace) |

## Repo layout

- `skills/` — the shipped skills (shared across all hosts)
- `.claude-plugin/`, `plugin.json` + `.github/plugin/`, `.cursor-plugin/` — per-host manifests, all pointing at `skills/`
- `install.sh` — symlink installer for non-marketplace hosts
- `evals/` — dev-only test suites for the skills (not shipped to users)
- `docs/design/` — design docs (architecture decisions)

## License

MIT — see [LICENSE](LICENSE).
