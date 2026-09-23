#!/usr/bin/env bash
set -euo pipefail

# Strix wrapper for this project.
# Resolves the LLM backend from your live opencode configuration
# (scripts/opencode-env.sh), loads .env if present, then runs `strix` with the
# project config file.
#
# Usage:
#   scripts/scan.sh [args...]        passes arguments straight through to strix
#   TARGETS=... scripts/scan.sh      default target via the TARGETS variable

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
CONFIG_FILE="${STRIX_CONFIG_FILE:-$PROJECT_ROOT/strix.config.json}"

# Load .env if present (without overriding already-exported variables).
if [[ -f "$PROJECT_ROOT/.env" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "$PROJECT_ROOT/.env"
  set +a
fi

# Resolve base URL, model and API key from the opencode configuration.
eval "$("$SCRIPT_DIR/opencode-env.sh")"

if [[ -z "${LLM_API_KEY:-}" ]]; then
  echo "ERROR: no LLM API key found. Run 'opencode providers login' or set LLM_API_KEY in .env." >&2
  exit 1
fi

command -v strix >/dev/null 2>&1 || { echo "strix not found. Run: make setup" >&2; exit 1; }

echo "→ Strix config : $CONFIG_FILE"
echo "→ Model        : ${STRIX_LLM:-(unset)}"
echo "→ Endpoint     : $(printf '%s' "${LLM_API_BASE:-(unset)}" | sed -E 's#(https?://[^/]+)/.*#\1/***#')"
# Redact the key, only show that it is set.
echo "→ API key      : configured ✓"
echo "→ Target       : ${TARGETS:-<pass as args>}"
echo

LLM_API_KEY="$LLM_API_KEY" exec strix --config "$CONFIG_FILE" ${TARGETS:+-t "$TARGETS"} "$@"