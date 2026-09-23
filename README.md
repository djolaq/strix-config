# strix-config

Configuration and project scaffold to drive **[Strix](https://github.com/usestrix/strix)**
(open-source AI pentesting agents, docs: https://docs.strix.ai) with the **same LLM backend
your opencode already uses** — resolved automatically from your opencode configuration at
runtime, so nothing client-specific is committed to this repository.

This repository is a **configuration hub**: it does not contain an app to scan, but
everything needed to run testing campaigns against your targets (code, web, API).

## Why your opencode LLM?

Strix agents work best on a model that already handles tool calling reliably. Your opencode
uses an OpenAI-compatible provider configured in `opencode.jsonc` (endpoint, model) with the
API key stored in `~/.local/share/opencode/auth.json`. `scripts/opencode-env.sh` reads those
files live and exports:

- `LLM_API_BASE` — the provider base URL,
- `STRIX_LLM`    — the model in LiteLLM form (`openai/<model-id>`),
- `LLM_API_KEY`  — the API key.

Strix then hits the same endpoint with the same model you use in opencode — no extra setup.

```
Strix agents  ──►  your opencode LLM provider (OpenAI-compatible endpoint) — signed commits ✓
                    STRIX_LLM     = openai/<model-id from opencode.jsonc>
                    LLM_API_KEY   = from opencode auth.json
```

> Change models/providers in your opencode config and this project follows automatically.

## Install (once)

```bash
make setup    # installs the Strix CLI (curl https://strix.ai/install)
make doctor   # checks Docker, config and LLM resolution
make env      # optional: creates .env to override defaults
```

Prerequisites: Docker running + a working opencode login (`opencode providers login`).

## Run a scan

```bash
# Deep scan on a target
make scan TARGET=https://staging.example.com

# Quick headless scan (CI/local), with a budget cap
make scan-quick TARGET=./my-app BUDGET=5 TURNS=200

# Headless scan scoped to the current branch diff vs main (PR)
make scan-ci TARGET=./

# Multiple targets from a file
scripts/scan.sh --target-list targets/example.targets

# Custom instructions
scripts/scan.sh --target https://app.com --instruction-file instructions/pentest.md

# View a run in the local dashboard
make view            # latest run
make view RUN=name   # a specific run
```

### Target / budget variables

| Variable | Purpose                     | Example                          |
|----------|-----------------------------|----------------------------------|
| `TARGET` | Target (for make targets)   | `make scan TARGET=https://x.com` |
| `BUDGET` | Max LLM spend in USD        | `BUDGET=5`                        |
| `TURNS`  | Max turns per agent         | `TURNS=200`                       |
| `RUN`    | Run name for `strix view`   | `RUN=my-run`                      |

Results land under `strix_runs/<run>/`: `vulnerabilities.json`, `vulnerabilities.csv`,
`findings.sarif`, one Markdown report per finding, and `events.jsonl` (light LLM telemetry).

## LLM configuration

- **`strix.config.json`** → project config passed via `strix --config`. No secrets, no
  client-specific endpoint.
- **`scripts/opencode-env.sh`** → resolves base URL, model and key from your opencode
  config. Existing env vars and `.env` override it.
- **`.env`** → optional overrides (see `.env.example`).
- **Useful settings** (see [docs](https://docs.strix.ai/advanced/configuration)):
  `STRIX_REASONING_EFFORT`, `STRIX_DEDUPE_MODEL` (cheaper model for dedup), timeouts,
  web search (`EXA`/`PERPLEXITY` for OSINT).

| Variable                 | Resolved from                                    |
|--------------------------|--------------------------------------------------|
| `STRIX_LLM`              | `openai/<model-id>` in your `opencode.jsonc`     |
| `LLM_API_BASE`           | `options.baseURL` in your `opencode.jsonc`       |
| `LLM_API_KEY`            | key in `~/.local/share/opencode/auth.json`       |
| `STRIX_REASONING_EFFORT` | `high` (default in `strix.config.json`)          |

> **Tool calls**: Strix requires structured `tool_calls` from the model. Infomaniak
> `/Kimi-K2.6` returns them correctly (verified). If you switch models, prefer one with
> `tool_call: true` on the same endpoint.

## CI / GitHub Actions

`.github/workflows/strix-pentest.yml` scans every PR in `quick` mode, scoped to the diff.
Configure three repository/organization secrets (your values, never committed):

- `STRIX_LLM`    → `openai/<model-id>`
- `LLM_API_BASE` → your provider base URL
- `LLM_API_KEY`  → your provider API key

## Drive Strix from opencode

The [official skills](https://docs.strix.ai/integrations/coding-agents) teach opencode to
launch pentests, remediate findings and wire up CI:

```bash
npx skills add usestrix/strix            # installs the 9 skills (Claude Code, opencode, …)
# then, inside opencode:
#   "Pentest this repo with Strix (quick mode, $10 budget) and summarize the findings."
#   "Fix the critical/high findings from the last run, then re-scan to verify."
```

## Layout

```
├── .env.example            # optional override template (copy to .env)
├── .github/workflows/      # CI: Strix scan on every PR
├── instructions/pentest.md # default instructions (--instruction-file)
├── scripts/opencode-env.sh # resolves LLM backend from the live opencode config
├── scripts/scan.sh         # wrapper: resolve LLM + strix --config
├── strix.config.json       # project config (generic, secret-free)
├── targets/                # target-list files (--target-list)
└── Makefile                # setup / env / doctor / scan / view / clean
```

## Disclaimer

Strix actively tests the targets you point it at. **Only test systems you own or have
explicit written permission to test**, and stay within the agreed scope.