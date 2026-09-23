#!/usr/bin/env bash
set -euo pipefail

# Wrapper Strix pour ce projet.
# Charge .env (secrets) puis lance `strix` avec la config du projet.
#
# Usage:
#   scripts/scan.sh [args...]        passe les arguments tels quels à strix
#   TARGETS=... scripts/scan.sh      cible par défaut via la variable TARGETS

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
CONFIG_FILE="${STRIX_CONFIG_FILE:-$PROJECT_ROOT/strix.config.json}"

# Charge .env s'il existe (sans écraser les variables déjà exportées).
if [[ -f "$PROJECT_ROOT/.env" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "$PROJECT_ROOT/.env"
  set +a
fi

# Vérifications de base.
command -v strix >/dev/null 2>&1 || { echo "strix introuvable. Lancez: make setup" >&2; exit 1; }

if [[ -z "${LLM_API_KEY:-}" ]]; then
  echo "ERREUR : LLM_API_KEY non définie. Renvoie vers Makefile->env ou opencode providers login." >&2
  exit 1
fi

echo "→ Config Strix : $CONFIG_FILE"
echo "→ Modèle LLM    : $STRIX_LLM ($LLM_API_BASE)"
echo "→ Cible         : ${TARGETS:-<à passer en args>}"
echo

exec strix --config "$CONFIG_FILE" ${TARGETS:+-t "$TARGETS"} "$@"