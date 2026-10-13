#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
python3 "$SCRIPT_DIR/src/process_applications.py" \
  --input-dir "$SCRIPT_DIR/input" \
  --output-dir "$SCRIPT_DIR/output"
