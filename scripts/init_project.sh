#!/usr/bin/env bash
# ACS v2 — Per-project init
# Run from the ROOT of any project to add ACS contract enforcement.
# Creates .acs/contract.json interactively.
# This file gets committed to the project repo.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ACS_REPO="$(dirname "$SCRIPT_DIR")"
PROJECT_ROOT="$(pwd)"
STARTERS_DIR="$ACS_REPO/templates/contracts"

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

# Project name
read -rp "Project name (e.g. WebBuilder, ConsumifyApp): " PROJECT_NAME

# Starter selection
echo ""
echo "Choose a starter contract, or start blank:"
echo "  1) nextjs-web-app        — Next.js app with auth, email, billing, DB"
echo "  2) stripe-integration    — Any project with Stripe payments"
echo "  3) html-css-pipeline     — HTML/CSS generation with post-processors"
echo "  4) database-schema       — Prisma/Drizzle schema + migrations"
echo "  5) auth-email            — Magic link / token-based auth"
echo "  6) blank                 — Start empty, add rules as incidents occur"
echo ""
read -rp "Starter [1-6]: " STARTER_CHOICE

STARTER_PATTERNS=()
STARTER_RULES=()

load_starter() {
    local file="$1"
    if [[ -f "$file" ]]; then
        # Extract pipeline_files array values
        mapfile -t STARTER_PATTERNS < <(python3 -c "
import json, sys
with open('$file') as f:
    d = json.load(f)
for p in d.get('pipeline_files', []):
    print(p)
" 2>/dev/null)
        # Extract rules array values
        mapfile -t STARTER_RULES < <(python3 -c "
import json, sys
with open('$file') as f:
    d = json.load(f)
for r in d.get('rules', []):
    print(r)
" 2>/dev/null)
        echo ""
        echo "Starter loaded. Pipeline files:"
        for p in "${STARTER_PATTERNS[@]}"; do echo "  - $p"; done
        echo ""
        echo "Starter rules:"
        for r in "${STARTER_RULES[@]}"; do echo "  • $r"; done
        echo ""
        echo "You can add more patterns and rules after the starter loads."
    else
        echo "⚠ Starter file not found: $file — falling back to blank."
    fi
}

case "$STARTER_CHOICE" in
    1) load_starter "$STARTERS_DIR/nextjs-web-app.json" ;;
    2) load_starter "$STARTERS_DIR/stripe-integration.json" ;;
    3) load_starter "$STARTERS_DIR/html-css-pipeline.json" ;;
    4) load_starter "$STARTERS_DIR/database-schema.json" ;;
    5) load_starter "$STARTERS_DIR/auth-email.json" ;;
    *) echo "(Starting blank)" ;;
esac

# Optional docs paths
read -rp "Path to CONTRACT.md relative to project root (or press Enter to skip): " CONTRACT_DOC
read -rp "Path to SMOKE-TEST.md relative to project root (or press Enter to skip): " SMOKE_TEST
read -rp "Path to SESSION-GATE.md relative to project root (or press Enter to skip): " SESSION_GATE

# Additional pipeline file patterns
echo ""
echo "Add MORE pipeline file patterns (beyond the starter, if any)."
echo "These are the files where a contract check fires before every edit."
echo "Enter one pattern per line. Press Enter on empty line when done."
echo "(Examples: component-assembler.ts, style-swap/route.ts)"
echo ""
EXTRA_PATTERNS=()
while true; do
    read -rp "  Pattern (or Enter to finish): " PATTERN
    [[ -z "$PATTERN" ]] && break
    EXTRA_PATTERNS+=("$PATTERN")
done

# Additional rules
echo ""
echo "Add MORE rules (beyond the starter, if any)."
echo "Write rules from bugs you already know about — not aspirational guidelines."
echo "Enter one rule per line. Press Enter on empty line when done."
echo ""
EXTRA_RULES=()
while true; do
    read -rp "  Rule (or Enter to finish): " RULE
    [[ -z "$RULE" ]] && break
    EXTRA_RULES+=("$RULE")
done

# Merge starter + extra
ALL_PATTERNS=("${STARTER_PATTERNS[@]}" "${EXTRA_PATTERNS[@]}")
ALL_RULES=("${STARTER_RULES[@]}" "${EXTRA_RULES[@]}")

# Build JSON arrays
build_json_array() {
    local arr=("$@")
    local result=""
    for item in "${arr[@]}"; do
        # Escape double quotes inside item
        escaped="${item//\"/\\\"}"
        result+="    \"$escaped\",\n"
    done
    # Remove trailing comma+newline
    echo -e "${result%,\\n}"
}

PATTERNS_JSON=$(build_json_array "${ALL_PATTERNS[@]}")
RULES_JSON=$(build_json_array "${ALL_RULES[@]}")

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
echo "  1. Review and edit .acs/contract.json — adjust patterns to match your actual file paths"
echo "  2. git add .acs/contract.json && git commit -m 'Add ACS contract config'"
echo "  3. Contract enforcement is now active for this project."
echo ""
echo "Growing the contract over time:"
echo "  • After any bug fix on a pipeline file: log the failure class in your session doc"
echo "  • When the same class of failure occurs a second time: add a rule to contract.json"
echo "  • Keep rules to ~10 max — ranked by frequency × blast radius. Prune rules whose"
echo "    bug class is now covered by type checking or automated tests."
echo ""
echo "Copy the ACS CLAUDE.md template into your project:"
echo "  cp $ACS_REPO/templates/CLAUDE.md ./CLAUDE.md"
echo "  (then customise the Project section)"
