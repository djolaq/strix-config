SHELL := /usr/bin/env bash
.DEFAULT_GOAL := help

CONFIG := $(CURDIR)/strix.config.json
ENV_FILE := $(CURDIR)/.env

.PHONY: help setup env doctor scan scan-quick scan-ci view targets clean

help: ## Show available targets
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'

setup: ## Install Strix (latest CLI)
	curl -sSL https://strix.ai/install | bash
	strix --version

env: ## Create .env from .env.example (optional overrides)
	@if [ ! -f $(ENV_FILE) ]; then cp .env.example $(ENV_FILE); echo "→ .env created. Only needed for overrides."; else echo ".env already present."; fi

doctor: ## Check Docker, config and LLM resolution
	@echo "— Strix —"; strix --version
	@command -v docker >/dev/null && docker info --format 'Docker OK: {{.ServerVersion}}' || echo "Docker missing/stopped"
	@echo "— Config —"; [ -f $(CONFIG) ] && echo "strix.config.json OK ($(CONFIG))"
	@bash -n scripts/scan.sh && echo "scripts/scan.sh OK (syntax)" && bash -n scripts/opencode-env.sh && echo "scripts/opencode-env.sh OK (syntax)"
	@bash -c 'eval "$$(scripts/opencode-env.sh)"; \
		if [ -n "$$LLM_API_KEY" ]; then echo "LLM key resolved ✓"; else echo "LLM key MISSING (opencode providers login, or LLM_API_KEY in .env)"; fi; \
		echo "Model     : $${STRIX_LLM:-(unset, resolved at runtime)}"; \
		base="$${LLM_API_BASE:-(unset, resolved at runtime)}"; \
		echo "Endpoint  : $$(printf "%s" "$$base" | sed -E "s#(https?://[^/]+)/.*#\1/***#")"; \
	'

scan: $(ENV_FILE) ## Deep pentest on $(TARGET)
	TARGETS=$(TARGET) scripts/scan.sh --scan-mode deep --max-turns 300
	@echo "→ Results: make view (latest run)"

scan-quick: $(ENV_FILE) ## Quick headless scan on $(TARGET)
	TARGETS=$(TARGET) scripts/scan.sh --scan-mode quick --max-budget "$(BUDGET)" --max-turns "$(TURNS)" --non-interactive

scan-ci: $(ENV_FILE) ## Headless scan scoped to the current branch diff vs main
	TARGETS=$(TARGET) scripts/scan.sh --scan-mode quick --scope-mode diff --diff-base origin/main --non-interactive

view: ## Open the local viewer on the latest run (or $(RUN))
	strix view $(RUN)

targets: ## Generate targets.txt from targets/*.targets
	@cat targets/*.targets | grep -v '^\s*#' | grep -v '^\s*$$' > targets.txt
	@echo "→ targets.txt created with $$(wc -l < targets.txt) target(s)"

clean: ## Remove local scan results
	rm -rf strix_runs targets.txt

$(ENV_FILE):
	@echo ".env missing. Run: make env"