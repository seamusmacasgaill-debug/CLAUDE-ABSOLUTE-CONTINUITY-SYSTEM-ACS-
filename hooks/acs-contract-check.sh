#!/usr/bin/env bash
# ACS v2 — Contract enforcement hook
# Fires before every Edit/Write tool call.
# If the target file is listed in .acs/contract.json for the current project,
# outputs the relevant contract rules into the conversation.
# Exits 0 always — warns but never blocks.

set -euo pipefail

# --- Parse file_path from stdin (Claude Code passes tool input as JSON) ---
RAW=$(cat)
FILE_PATH=$(echo "$RAW" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    # Handle both {file_path:...} and {tool_input:{file_path:...}}
    if 'file_path' in data:
        print(data['file_path'])
    elif 'tool_input' in data and 'file_path' in data['tool_input']:
        print(data['tool_input']['file_path'])
except:
    pass
" 2>/dev/null || echo "")

# No file path extracted — nothing to check
[[ -z "$FILE_PATH" ]] && exit 0

# --- Locate the nearest .acs/contract.json by walking up from the file's directory ---
DIR="$(dirname "$FILE_PATH")"
CONTRACT_JSON=""
while [[ "$DIR" != "/" ]]; do
    if [[ -f "$DIR/.acs/contract.json" ]]; then
        CONTRACT_JSON="$DIR/.acs/contract.json"
        PROJECT_ROOT="$DIR"
        break
    fi
    DIR="$(dirname "$DIR")"
done

# No contract config found for this project — silent exit
[[ -z "$CONTRACT_JSON" ]] && exit 0

# --- Check if this file matches any pattern in pipeline_files ---
MATCHED=$(python3 -c "
import json, sys
with open('$CONTRACT_JSON') as f:
    cfg = json.load(f)
patterns = cfg.get('pipeline_files', [])
filepath = '$FILE_PATH'
for p in patterns:
    if p in filepath:
        print(p)
        break
" 2>/dev/null || echo "")

# File is not a pipeline file — silent exit
[[ -z "$MATCHED" ]] && exit 0

# --- File matched. Output the contract reminder. ---
CFG=$(python3 -c "import json; cfg=json.load(open('$CONTRACT_JSON')); print(json.dumps(cfg, indent=2))" 2>/dev/null)
PROJECT=$(python3 -c "import json; cfg=json.load(open('$CONTRACT_JSON')); print(cfg.get('project','this project'))" 2>/dev/null)
CONTRACT_DOC=$(python3 -c "import json; cfg=json.load(open('$CONTRACT_JSON')); print(cfg.get('contract_doc',''))" 2>/dev/null)
RULES=$(python3 -c "
import json
cfg = json.load(open('$CONTRACT_JSON'))
rules = cfg.get('rules', [])
for i, r in enumerate(rules, 1):
    print(f'  {i}. {r}')
" 2>/dev/null)

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  ACS CONTRACT CHECK — $PROJECT"
echo "╠══════════════════════════════════════════════════════════════╣"
echo "║  File: $FILE_PATH"
echo "║  Matched pattern: $MATCHED"
echo "╠══════════════════════════════════════════════════════════════╣"
echo "║  HARD RULES FOR THIS FILE:"
echo "$RULES"
echo "╠══════════════════════════════════════════════════════════════╣"
echo "║  SAME-CLASS SWEEP REQUIRED before marking fix COMPLETE:"
echo "║  1. Does the same class of bug exist in the other post-processor?"
echo "║  2. Does the fix apply to Bold AND Luxury palettes?"
echo "║  3. Checked all entry points, not just the one that broke?"
echo "╠══════════════════════════════════════════════════════════════╣"
if [[ -n "$CONTRACT_DOC" ]]; then
    FULL_CONTRACT_PATH="$PROJECT_ROOT/$CONTRACT_DOC"
    if [[ -f "$FULL_CONTRACT_PATH" ]]; then
        echo "║  Full contract: $FULL_CONTRACT_PATH"
        echo "╚══════════════════════════════════════════════════════════════╝"
        echo ""
        # Output the blast zone matrix section from the contract doc
        python3 -c "
import sys
with open('$FULL_CONTRACT_PATH') as f:
    content = f.read()
# Extract Blast zone matrix section
start = content.find('## Blast zone matrix')
if start >= 0:
    end = content.find('\n## ', start + 1)
    section = content[start:end if end > 0 else start+3000]
    print(section[:2000])
" 2>/dev/null
    else
        echo "║  Full contract: $CONTRACT_DOC (relative to project root)"
        echo "╚══════════════════════════════════════════════════════════════╝"
    fi
else
    echo "╚══════════════════════════════════════════════════════════════╝"
fi

exit 0
