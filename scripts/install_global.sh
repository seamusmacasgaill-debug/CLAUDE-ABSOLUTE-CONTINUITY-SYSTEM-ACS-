#!/usr/bin/env bash
# ACS v2 — Global install
# Run ONCE on any machine. Installs the hook script and wires ~/.claude/settings.json.
# After this, any project with a .acs/contract.json gets automatic contract enforcement.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ACS_REPO="$(dirname "$SCRIPT_DIR")"
CLAUDE_DIR="$HOME/.claude"
HOOKS_DIR="$CLAUDE_DIR/hooks"
SETTINGS="$CLAUDE_DIR/settings.json"

echo "ACS v2 — Global Install"
echo "========================"
echo "ACS repo: $ACS_REPO"
echo "Installing to: $CLAUDE_DIR"
echo ""

# 1. Create hooks directory
mkdir -p "$HOOKS_DIR"

# 2. Install hook script
cp "$ACS_REPO/hooks/acs-contract-check.sh" "$HOOKS_DIR/"
chmod +x "$HOOKS_DIR/acs-contract-check.sh"
echo "✓ Hook script installed: $HOOKS_DIR/acs-contract-check.sh"

# 3. Create or update settings.json
if [[ -f "$SETTINGS" ]]; then
    # Merge — check if hooks already configured
    if grep -q "acs-contract-check" "$SETTINGS" 2>/dev/null; then
        echo "✓ settings.json already configured for ACS hooks"
    else
        echo "⚠ settings.json exists but has no ACS hooks."
        echo "  Add manually:"
        echo '  "hooks": {"PreToolUse": [{"matcher": "Edit|Write", "hooks": [{"type": "command", "command": "bash ~/.claude/hooks/acs-contract-check.sh"}]}]}'
        echo "  Existing settings.json preserved — not overwritten."
    fi
else
    cat > "$SETTINGS" <<'EOF'
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "bash ~/.claude/hooks/acs-contract-check.sh"
          }
        ]
      }
    ]
  }
}
EOF
    echo "✓ settings.json created with PreToolUse hook"
fi

echo ""
echo "Global install complete."
echo ""
echo "Next step: for each project that needs contract enforcement, run:"
echo "  bash $ACS_REPO/scripts/init_project.sh"
echo "from the project root directory."
