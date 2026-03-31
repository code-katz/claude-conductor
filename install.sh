#!/usr/bin/env bash
# install.sh — Install claude-conductor skill and CLI
# Usage: bash install.sh
#
# What this does:
#   1. Installs the conductor skill to ~/.claude/skills/conductor/
#   2. Installs slash commands to ~/.claude/commands/
#   3. Installs the claude-conductor CLI to ~/.local/bin/
#   4. Checks that ~/.local/bin is on your PATH

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_SRC="$REPO_DIR/SKILL.md"
SKILL_DST="$HOME/.claude/skills/conductor"
COMMANDS_SRC="$REPO_DIR/commands"
COMMANDS_DST="$HOME/.claude/commands"
BIN_SRC="$REPO_DIR/bin/claude-conductor"
BIN_DST="$HOME/.local/bin/claude-conductor"

bold()  { printf '\033[1m%s\033[0m' "$*"; }
green() { printf '\033[32m%s\033[0m' "$*"; }
yellow(){ printf '\033[33m%s\033[0m' "$*"; }
dim()   { printf '\033[2m%s\033[0m' "$*"; }

echo ""
echo "$(bold "claude-conductor installer")"
echo "────────────────────────────────────"
echo ""

# 1. Install skill
echo "Installing skill to $SKILL_DST ..."
mkdir -p "$SKILL_DST"
cp "$SKILL_SRC" "$SKILL_DST/SKILL.md"
echo "$(green "✓") Skill installed: $(dim "$SKILL_DST/SKILL.md")"
echo ""

# 2. Install slash commands
echo "Installing slash commands to $COMMANDS_DST ..."
mkdir -p "$COMMANDS_DST"
cp "$COMMANDS_SRC"/*.md "$COMMANDS_DST/"
echo "$(green "✓") Slash commands installed:"
for f in "$COMMANDS_SRC"/*.md; do
  echo "    $(dim "$(basename "$f")")"
done
echo ""

# 3. Install CLI (symlink so updates in the repo take effect immediately)
echo "Installing CLI to $BIN_DST ..."
mkdir -p "$(dirname "$BIN_DST")"
ln -sf "$BIN_SRC" "$BIN_DST"
chmod +x "$BIN_SRC"
echo "$(green "✓") CLI symlinked: $(dim "$BIN_DST → $BIN_SRC")"
# Also install generate-dashboard
GEN_SRC="$REPO_DIR/bin/generate-dashboard"
GEN_DST="$HOME/.local/bin/generate-dashboard"
ln -sf "$GEN_SRC" "$GEN_DST"
chmod +x "$GEN_SRC"
echo "$(green "✓") Dashboard generator symlinked: $(dim "$GEN_DST → $GEN_SRC")"
echo ""

# 4. Live dashboard (optional, requires Node.js)
if [[ "${1:-}" == "--with-dashboard" ]]; then
  DASHBOARD_DIR="$REPO_DIR/dashboard"
  if [[ -f "$DASHBOARD_DIR/package.json" ]]; then
    echo "Installing live dashboard dependencies..."
    cd "$DASHBOARD_DIR" && npm install --silent 2>/dev/null
    echo "$(green "✓") Dashboard: installed ($(dim "node_modules in $DASHBOARD_DIR"))"
  else
    echo "$(yellow "!") Dashboard: package.json not found. Skipping."
  fi
else
  echo "$(dim "Dashboard: skipped (run install.sh --with-dashboard to enable)")"
fi
echo ""

# 5. PATH check
if echo "$PATH" | grep -q "$HOME/.local/bin"; then
  echo "$(green "✓") ~/.local/bin is already on your PATH."
else
  echo "$(yellow "!") ~/.local/bin is not on your PATH."
  echo ""
  echo "  Add it by appending to your shell config:"
  echo ""
  echo "    $(dim "# ~/.zshrc or ~/.bashrc")"
  echo "    export PATH=\"\$HOME/.local/bin:\$PATH\""
  echo ""
  echo "  Then reload your shell:"
  echo "    source ~/.zshrc   $(dim "# or ~/.bashrc")"
fi

echo ""
echo "$(bold "Done!") The conductor is ready."
echo ""
echo "Quick start:"
echo "  claude-conductor init              $(dim "# create SESSIONS.md in your project")"
echo "  claude-conductor status            $(dim "# show all active sessions")"
echo "  claude-conductor dashboard --live  $(dim "# real-time Node.js dashboard")"
echo "  claude-conductor help              $(dim "# full command reference")"
echo ""
echo "In Claude Code:"
echo "  /conductor                         $(dim "# show session status")"
echo "  /conductor start                   $(dim "# register sessions from /parallel")"
echo "  /conductor plan                    $(dim "# generate /parallel plan + register")"
echo "  /sessions                          $(dim "# alias for /conductor")"
echo ""
echo "$(bold "Works best with:")"
echo "  claude-team-cli                    $(dim "# personas and /parallel planning")"
echo "  claude-devlog-skill                $(dim "# auto-log session outcomes")"
echo "  claude-roadmap-skill               $(dim "# track sprint progress on roadmap")"
echo ""
