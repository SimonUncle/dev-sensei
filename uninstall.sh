#!/bin/bash

SKILLS_DIR="$HOME/.claude/skills"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🎋 dev-sensei uninstaller"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

SKILLS=(struggle-gate why-mode pattern-recognizer incident-mentor)
REMOVED=0

for skill in "${SKILLS[@]}"; do
  dest="$SKILLS_DIR/$skill"
  if [ -L "$dest" ]; then
    rm "$dest"
    echo "  ✅ Removed $skill"
    REMOVED=$((REMOVED + 1))
  else
    echo "  - $skill (not installed)"
  fi
done

echo ""
echo "Removed $REMOVED skills. Restart Claude Code to apply."
