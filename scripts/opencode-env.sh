#!/usr/bin/env bash
# Resolves the LLM backend (base URL, model, API key) from the user's own
# opencode configuration at runtime, so this repository never hardcodes any
# client-specific value (endpoint, account id, key).
#
# Resolution order (first hit wins):
#   1. existing shell env (LLM_API_BASE / STRIX_LLM / LLM_API_KEY)
#   2. credentials from opencode auth.json
#   3. endpoint + model from opencode.jsonc
#
# Usage: eval "$(scripts/opencode-env.sh)"
set -euo pipefail

pretty() { python3 - "$@" <<'PY'
import json, re, sys

def load_openconfig(path):
    text = open(path, encoding="utf-8").read()
    try:
        return json.loads(text)
    except json.JSONDecodeError:
        pass
    # Minimal JSONC support: strip // and /* */ comments outside strings.
    out, i, n, in_str, esc = [], 0, len(text), False, False
    while i < n:
        c = text[i]
        if in_str:
            out.append(c)
            if esc:
                esc = False
            elif c == "\\":
                esc = True
            elif c == '"':
                in_str = False
            i += 1
            continue
        if c == '"':
            in_str = True
            out.append(c); i += 1; continue
        if c == "/" and i + 1 < n and text[i + 1] == "/":
            while i < n and text[i] != "\n":
                i += 1
            continue
        if c == "/" and i + 1 < n and text[i + 1] == "*":
            i += 2
            while i + 1 < n and not (text[i] == "*" and text[i + 1] == "/"):
                i += 1
            i += 2
            continue
        out.append(c); i += 1
    return json.loads("".join(out))

def resolve(config_path, models_path):
    cfg = load_openconfig(config_path)
    providers = cfg.get("provider", {})
    disabled = set(cfg.get("disabled_providers", []))
    provider_id = None
    if providers.get("uinfomaniak"):
        provider_id = "uinfomaniak"
    else:
        for pid in providers:
            if pid in disabled:
                continue
            p = providers[pid]
            if isinstance(p, dict) and p.get("options", {}).get("baseURL") and isinstance(p.get("models"), dict) and p["models"]:
                provider_id = pid
                break
    if not provider_id:
        return None
    p = providers[provider_id]
    base = p.get("options", {}).get("baseURL", "")
    model_id = next(iter(p.get("models", {})))
    key = None
    try:
        auth = json.load(open(models_path, encoding="utf-8"))
    except Exception:
        auth = {}
    cand = [provider_id, provider_id.lstrip("u"), "infomaniak"]
    for pid in cand:
        v = auth.get(pid)
        if isinstance(v, dict) and v.get("key"):
            key = v["key"]
            break
    if not key:
        for v in auth.values():
            if isinstance(v, dict) and v.get("key"):
                key = v["key"]
                break
    return {"provider": provider_id, "base": base, "model": model_id, "key": key}

def main(argv):
    config_path = argv[0]
    if not config_path:
        return
    models_path = argv[1] if len(argv) > 1 else ""
    r = resolve(config_path, models_path)
    if not r:
        return
    if not __import__("os").environ.get("LLM_API_BASE") and r["base"]:
        print("export LLM_API_BASE=%r" % r["base"])
    if not __import__("os").environ.get("STRIX_LLM") and r["model"]:
        print("export STRIX_LLM=%r" % ("openai/" + r["model"]))
    if not __import__("os").environ.get("LLM_API_KEY") and r["key"]:
        print("export LLM_API_KEY=%r" % r["key"])

main(sys.argv[1:])
PY
}

CONFIG_SRC=""; AUTH_SRC=""
for p in \
  "/mnt/c/Users/johan/.config/opencode/opencode.jsonc" \
  "$HOME/.config/opencode/opencode.jsonc"; do
  [[ -f "$p" ]] && { CONFIG_SRC="$p"; break; }
done
for p in \
  "/mnt/c/Users/johan/.local/share/opencode/auth.json" \
  "$HOME/.local/share/opencode/auth.json"; do
  [[ -f "$p" ]] && { AUTH_SRC="$p"; break; }
done

[[ -n "$CONFIG_SRC" ]] && pretty "$CONFIG_SRC" "$AUTH_SRC"
exit 0