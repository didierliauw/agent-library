#!/usr/bin/env bash
# Exercises install.sh against a throwaway HOME so no real host dir is touched.
set -euo pipefail
REPO=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
export HOME="$TMP"

fail() { echo "FAIL: $1" >&2; exit 1; }

# 1. --dry-run changes nothing but reports the intended link
"$REPO/install.sh" cursor --dry-run >"$TMP/out" 2>&1
[[ ! -e "$TMP/.cursor/skills/scriptify" ]] || fail "dry-run created a link"
grep -q "would link" "$TMP/out" || fail "dry-run did not report intended link"

# 2. install creates a symlink pointing into the repo
"$REPO/install.sh" cursor >/dev/null
[[ -L "$TMP/.cursor/skills/scriptify" ]] || fail "install did not create symlink"
dest=$(readlink "$TMP/.cursor/skills/scriptify")
[[ "$dest" == "$REPO/skills/scriptify" ]] || fail "symlink points to: $dest"

# 2b. uninstall must NOT remove a foreign link (one not pointing into the repo)
ln -s /tmp/some-other-tool "$TMP/.cursor/skills/foreign"
"$REPO/install.sh" --uninstall cursor >/dev/null
[[ -L "$TMP/.cursor/skills/foreign" ]] || fail "uninstall removed a foreign link"
rm "$TMP/.cursor/skills/foreign"
# reinstall scriptify since the line above removed our cursor link
"$REPO/install.sh" cursor >/dev/null

# 3. re-install is idempotent
"$REPO/install.sh" cursor >/dev/null
[[ -L "$TMP/.cursor/skills/scriptify" ]] || fail "re-install broke the symlink"

# 4. codex/gemini share ~/.agents/skills
"$REPO/install.sh" codex >/dev/null
[[ -L "$TMP/.agents/skills/scriptify" ]] || fail "codex install did not link into ~/.agents/skills"

# 5. uninstall removes only our link
"$REPO/install.sh" --uninstall cursor >/dev/null
[[ ! -e "$TMP/.cursor/skills/scriptify" ]] || fail "uninstall did not remove link"

# 6. unknown host errors out
if "$REPO/install.sh" bogus >/dev/null 2>&1; then fail "unknown host did not error"; fi

echo "PASS: install.sh"
