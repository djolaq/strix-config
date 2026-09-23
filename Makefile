SHELL := /usr/bin/env bash
.DEFAULT_GOAL := help

CONFIG := $(CURDIR)/strix.config.json
ENV_FILE := $(CURDIR)/.env

.PHONY: help setup env doctor scan scan-quick scan-ci view targets clean

help: ## Affiche l'aide des cibles
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'

setup: ## Installe Strix + le client CLI le plus récent
	curl -sSL https://strix.ai/install | bash
	strix --version

env: ## Prépare .env à partir de .env.example
	@if [ ! -f $(ENV_FILE) ]; then cp .env.example $(ENV_FILE); echo "→ .env créé. Complétez LLM_API_KEY puis: make doctor"; else echo ".env déjà présent."; fi

doctor: ## Vérifie Docker, la config et les variables LLM
	@echo "— Strix —"; strix --version
	@command -v docker >/dev/null && docker info --format 'Docker OK: {{.ServerVersion}}' || echo "Docker absent/éteint"
	@echo "— Config —"; [ -f $(CONFIG) ] && echo "strix.config.json OK ($(CONFIG))"
	@bash -n scripts/scan.sh && echo "scripts/scan.sh OK (syntaxe)"
	@set -a; [ -f $(ENV_FILE) ] && . $(ENV_FILE); set +a; \
		[ -n "$$LLM_API_KEY" ] && echo "LLM_API_KEY définie ✓" || echo "LLM_API_KEY MANQUANTE (voir 'make env' puis remplir .env)"
	@echo "STRIX_LLM=$${STRIX_LLM:-(défaut openai/big-pickle)}  LLM_API_BASE=$${LLM_API_BASE:-https://opencode.ai/zen/v1}"

scan: $(ENV_FILE) ## Pentest complet (mode deep) sur $(TARGET)
	TARGETS=$(TARGET) scripts/scan.sh --scan-mode deep --max-turns 300
	@echo "→ Résultat: strix view (dernier run)"

scan-quick: $(ENV_FILE) ## Scan rapide (CI/local, headless) sur $(TARGET)
	TARGETS=$(TARGET) scripts/scan.sh --scan-mode quick --max-budget "$(BUDGET)" --max-turns "$(TURNS)" --non-interactive

scan-ci: $(ENV_FILE) ## Scan headless sur le diff de la branche courante vs main
	TARGETS=$(TARGET) scripts/scan.sh --scan-mode quick --scope-mode diff --diff-base origin/main --non-interactive

view: ## Ouvre le viewer local sur le dernier run (ou $(RUN))
	strix view $(RUN)

targets: ## Génère targets.txt depuis targets/*.targets
	@cat targets/*.targets | grep -v '^\s*#' | grep -v '^\s*$$' > targets.txt
	@echo "→ targets.txt crié avec $$(wc -l < targets.txt) cible(s)"

clean: ## Supprime les résultats de scan locaux
	rm -rf strix_runs targets.txt

$(ENV_FILE):
	@echo ".env absent. Lancez: make env"