#!/usr/bin/env bash
# Duology lint hook for Claude Code (opt-in).
#
# Runs after Claude edits or writes a .swift file. It lints that file with duo-lint
# and hands any iPhone Duo findings back to Claude as context. It never blocks:
# it always exits 0, and it stays silent when there is nothing to say.
#
# Turn it on:  export DUOLOGY_LINT_HOOK=1   (before you start Claude Code)
# Turn it off: unset DUOLOGY_LINT_HOOK

[ "${DUOLOGY_LINT_HOOK:-}" = "1" ] || exit 0

input=$(cat)

# Cheap filter before starting Python: only Swift files.
case "$input" in
  *'.swift"'*) ;;
  *) exit 0 ;;
esac

command -v python3 >/dev/null 2>&1 || exit 0

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
lint="$here/../skills/duo-lint/scripts/duo-lint.py"
[ -f "$lint" ] || exit 0

printf '%s' "$input" | python3 "$lint" --claude-hook 2>/dev/null || true
exit 0
