#!/bin/zsh
# Push current branch to both GitHub (origin) and Gitee (gitee).
# Run after every commit you want public.
#
# .dmg uploads to release pages still need to be done manually:
#   - GitHub: gh release create vX.Y.Z-fork file.dmg -R tongchen9538/opcode-fork
#   - Gitee:  https://gitee.com/ctcr/opcode-fork/releases/new (web UI upload)

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

BRANCH="$(git rev-parse --abbrev-ref HEAD)"
echo "==> pushing $BRANCH to GitHub (origin)"
git push origin "$BRANCH"

echo "==> pushing $BRANCH to Gitee (gitee)"
git push gitee "$BRANCH"

echo
echo "Code synced. To publish a release:"
echo "  1. GitHub: gh release create vX.Y.Z-fork <dmg> -R tongchen9538/opcode-fork"
echo "  2. Gitee:  open https://gitee.com/ctcr/opcode-fork/releases/new"
echo "             tag = same as GitHub, attach the same .dmg"
echo "  3. Update Casks/opcode-fork{,-cn,-gitee}.rb sha256 + version"
echo "     and run scripts/push-tap.sh"
