#!/usr/bin/env bash
# Scaffold a new game project from starter-kit/.
# Usage: tools/new_project.sh <dest_dir> "<Project Name>"
# Copies starter-kit/ into dest_dir (created if missing, must be empty), replaces __PROJECT_NAME__ (display name)
# and __PROJECT_SLUG__ (file-safe name) in the text files, runs git init, and prints next steps.
set -euo pipefail
KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/starter-kit"
[[ $# -eq 2 ]] || { echo "usage: tools/new_project.sh <dest_dir> \"<Project Name>\"" >&2; exit 2; }
DEST="$1"; NAME="$2"
[[ -d "$KIT" ]] || { echo "new_project: $KIT not found" >&2; exit 1; }
[[ -n "${NAME// }" ]] || { echo "new_project: project name is empty" >&2; exit 2; }
if [[ -d "$DEST" && -n "$(ls -A "$DEST")" ]]; then echo "new_project: $DEST exists and is not empty" >&2; exit 1; fi
mkdir -p "$DEST"
cp -a "$KIT"/. "$DEST"/
rm -f "$DEST/.gdignore"  # the kit is hidden from the Skate Park project itself; the new project must not be
rm -rf "$DEST/.godot" "$DEST/build" "$DEST/out"

SLUG="$(printf '%s' "$NAME" | tr -c 'A-Za-z0-9\n' '-' | sed 's/--*/-/g; s/^-//; s/-$//')"
[[ -n "$SLUG" ]] || SLUG="game"
esc() { printf '%s' "$1" | sed -e 's/[\\&|]/\\&/g'; }
N="$(esc "$NAME")"; S="$(esc "$SLUG")"
grep -rlI --exclude-dir=.git -e '__PROJECT_' "$DEST" | while IFS= read -r f; do
  sed -i "s|__PROJECT_NAME__|$N|g; s|__PROJECT_SLUG__|$S|g" "$f"
done

(cd "$DEST" && git init -q -b main 2>/dev/null || git init -q)
echo "new_project: created '$NAME' in $DEST (file name: $SLUG)"
cat <<EOT
Next steps:
  1. cd $DEST && tools/check_all.sh          # should be all green on minute one
  2. Fill in CLAUDE.md and docs/agent_brief.md; read docs/new_project_checklist.md
  3. Create the GitHub repo:  gh repo create <owner>/$SLUG --private --source=. --remote=origin
  4. git add -A && git commit -m "Start from starter kit" && git push -u origin main
  5. CI (.github/workflows/checks.yml) runs unit, lint and sims on the push; confirm it is green
EOT
