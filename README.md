# strix-config

Config et projet prêts à l'emploi pour piloter **[Strix](https://github.com/usestrix/strix)**
(agents AI de pentest, docs : https://docs.strix.ai) avec **OpenCode Zen** comme LLM,
c'est-à-dire le même fournisseur que celui utilisé par votre opencode.

Ce dépôt est un **hub de configuration** : il ne contient pas d'application à scanner,
mais tout le nécessaire pour lancer des campagnes de test sur vos cibles (code, web, API).

## Pourquoi OpenCode Zen ?

Votre opencode est branché sur le provider `opencode` = **OpenCode Zen**
(`https://opencode.ai/zen/v1`, variable `OPENCODE_API_KEY`), et votre modèle par défaut est
`big-pickle`. Ce projet réutilise exactement cette infrastructure : les agents Strix
appellent le même endpoint avec le même modèle, sans clé API supplémentaire.

```
Strix agents  ──►  Zen (https://opencode.ai/zen/v1)   ⇐ même endpoint que opencode
                    STRIX_LLM = openai/big-pickle
```

## Installation (une seule fois)

```bash
make setup    # installe la CLI strix (curl https://strix.ai/install)
make env      # crée .env  puis complétez :  LLM_API_KEY=<votre clé Zen>
make doctor   # vérifie Docker, la config et les variables
```

> Clé Zen : `opencode providers login` (choisissez `opencode`) et reportez la clé dans `.env`.

## Lancer un scan

```bash
# Scan deep sur une cible
make scan TARGET=https://staging.example.com

# Scan rapide headless (CI/local), avec budget
make scan-quick TARGET=./mon-app BUDGET=5 TURNS=200

# Scan headless limité aux fichiers modifiés vs main (PR)
make scan-ci TARGET=./

# Cibles multiples depuis un fichier
scripts/scan.sh --target-list targets/example.targets

# Consignes personnalisées
scripts/scan.sh --target https://app.com --instruction-file instructions/pentest.md

# Visualiser un run dans le dashboard local
make view            # dernier run
make view RUN=nom    # run précis
```

### Variables de cible / budget

| Variable | Rôle                          | Exemple                          |
|----------|-------------------------------|----------------------------------|
| `TARGET` | Cible (pour les cibles make)  | `make scan TARGET=https://x.com` |
| `BUDGET` | Cap de dépense LLM en USD     | `BUDGET=5`                        |
| `TURNS`  | Max de tours par agent        | `TURNS=200`                       |
| `RUN`    | Nom d'un run pour `strix view`| `RUN=my-run`                      |

Résultats sous `strix_runs/<run>/` : `vulnerabilities.json`, `vulnerabilities.csv`,
`findings.sarif`, rapport Markdown par finding, `events.jsonl` (télémétrie LLM light).

## Configuration LLM

- **`strix.config.json`** → config projet passée à `strix --config`. Sans secret.
- **`.env`** → secrets locaux (`LLM_API_KEY`…). Chargé par `scripts/scan.sh` et les cibles make.
- **Options utiles** (voir [docs](https://docs.strix.ai/advanced/configuration)) :
  `STRIX_REASONING_EFFORT`, `STRIX_DEDUPE_MODEL` (modèle plus léger pour la dédup), timeout,
  recherche web (`EXA`/`PERPLEXITY` pour l'OSINT).

| Variable              | Valeur projet                               |
|-----------------------|---------------------------------------------|
| `STRIX_LLM`           | `openai/big-pickle`                         |
| `LLM_API_BASE`        | `https://opencode.ai/zen/v1`                |
| `LLM_API_KEY`         | votre clé OpenCode Zen (dans `.env`)        |
| `STRIX_REASONING_EFFORT` | `high`                                    |

> **Tool calls** : Strix exige des `tool_calls` structurés en sortie. Zen et `big-pickle`
> renvoient des appels structurés ; si un autre modèle choisissait d'imprimer les appels en
> texte, basculez sur un modèle compatible (voir docs « Local Models »).

## CI / GitHub Actions

Le workflow `.github/workflows/strix-pentest.yml` scanne chaque PR en mode `quick` restreint
au diff. Configurez trois secrets au niveau du dépôt ou de l'organisation :

- `STRIX_LLM`    → `openai/big-pickle`
- `LLM_API_BASE` → `https://opencode.ai/zen/v1`
- `LLM_API_KEY`  → votre clé Zen

## Piloter Strix depuis opencode

Les [skills officiels](https://docs.strix.ai/integrations/coding-agents) donnent à opencode le
réflexe de lancer des pentests, de corriger les findings et d'ajouter du CI :

```bash
npx skills add usestrix/strix            # installe les 9 skills (Claude Code, opencode, …)
# puis, dans opencode :
#   "Pentest ce repo avec Strix (quick mode, $10 budget) et résume les findings."
#   "Corrige les findings critical/high du dernier run puis re-scanne pour vérifier."
```

## Structure

```
├── .env.example            # gabarit de variables (copier en .env)
├── .github/workflows/      # CI : scan Strix sur chaque PR
├── instructions/pentest.md # consignes par défaut (--instruction-file)
├── scripts/scan.sh         # wrapper : charge .env + strix --config
├── strix.config.json       # config projet (LLM = Zen), sans secret
├── targets/                # fichiers de cibles (--target-list)
└── Makefile                # setup / env / doctor / scan / view / clean
```

## Avertissement

Strix teste réellement les cibles visées. **N'utilisez que des systèmes que vous possédez ou
que vous êtes explicitement autorisé à tester**, et restez dans le périmètre convenu.