#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILLS_DIR="$HOME/.claude/skills"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🎋 dev-sensei installer"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

mkdir -p "$SKILLS_DIR"

SKILLS=(struggle-gate why-mode pattern-recognizer incident-mentor)
INSTALLED=0

for skill in "${SKILLS[@]}"; do
  src="$SCRIPT_DIR/skills/$skill"
  dest="$SKILLS_DIR/$skill"

  if [ -L "$dest" ]; then
    echo "  ↻ $skill (updating link)"
    rm "$dest"
  elif [ -d "$dest" ]; then
    echo "  ⚠ $skill already exists (not a symlink, skipping)"
    continue
  fi

  ln -s "$src" "$dest"
  echo "  ✅ $skill"
  INSTALLED=$((INSTALLED + 1))
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Installed $INSTALLED skills to $SKILLS_DIR"
echo ""
echo "Restart Claude Code to activate."
echo "Run ./uninstall.sh to remove."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━"
