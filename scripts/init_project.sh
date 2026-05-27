#!/usr/bin/env bash
# ACS v2 — Per-project init
# Run from the ROOT of any project to add ACS contract enforcement.
# Creates .acs/contract.json interactively.
# This file gets committed to the project repo.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ACS_REPO="$(dirname "$SCRIPT_DIR")"
PROJECT_ROOT="$(pwd)"

echo "ACS v2 — Project Init"
echo "====================="
echo "Project root: $PROJECT_ROOT"
echo ""

# Check global hooks are installed
if [[ ! -f "$HOME/.claude/hooks/acs-contract-check.sh" ]]; then
    echo "⚠ Global ACS hooks not installed."
    echo "  Run first: bash $ACS_REPO/scripts/install_global.sh"
    exit 1
fi

mkdir -p "$PROJECT_ROOT/.acs"

# Interactive setup
read -rp "Project name (e.g. WebBuilder, ConsumifyApp): " PROJECT_NAME
read -rp "Path to CONTRACT.md relative to project root (or press Enter to skip): " CONTRACT_DOC
read -rp "Path to SMOKE-TEST.md relative to project root (or press Enter to skip): " SMOKE_TEST
read -rp "Path to SESSION-GATE.md relative to project root (or press Enter to skip): " SESSION_GATE

echo ""
echo "Now enter the file patterns that identify PIPELINE/CRITICAL files."
echo "These are the files where a contract check fires before every edit."
echo "Enter one pattern per line. Press Enter on empty line when done."
echo "(Examples: component-assembler.ts, style-swap/route.ts, page.tsx)"
echo ""
PATTERNS=()
while true; do
    read -rp "  Pattern (or Enter to finish): " PATTERN
    [[ -z "$PATTERN" ]] && break
    PATTERNS+=("\"$PATTERN\"")
done

echo ""
echo "Now enter the hard rules for these files."
echo "These are injected into the conversation before every edit."
echo "Enter one rule per line. Press Enter on empty line when done."
echo ""
RULES=()
while true; do
    read -rp "  Rule (or Enter to finish): " RULE
    [[ -z "$RULE" ]] && break
    RULES+=("\"$RULE\"")
done

# Build JSON
PATTERNS_JSON=$(printf '%s,\n    ' "${PATTERNS[@]}" | sed 's/,\n    $//')
RULES_JSON=$(printf '%s,\n    ' "${RULES[@]}" | sed 's/,\n    $//')

cat > "$PROJECT_ROOT/.acs/contract.json" <<EOF
{
  "project": "$PROJECT_NAME",
  "contract_doc": "$CONTRACT_DOC",
  "pipeline_files": [
    $PATTERNS_JSON
  ],
  "rules": [
    $RULES_JSON
  ],
  "quality_gate": "6-star",
  "smoke_test": "$SMOKE_TEST",
  "session_gate": "$SESSION_GATE"
}
EOF

echo ""
echo "✓ Created: $PROJECT_ROOT/.acs/contract.json"
echo ""
echo "Next steps:"
echo "  1. Review and edit .acs/contract.json"
echo "  2. git add .acs/contract.json && git commit -m 'Add ACS contract config'"
echo "  3. Contract enforcement is now active for this project."
echo ""
echo "Copy the ACS CLAUDE.md template into your project:"
echo "  cp $ACS_REPO/templates/CLAUDE.md ./CLAUDE.md"
echo "  (then customise the Project section)"
