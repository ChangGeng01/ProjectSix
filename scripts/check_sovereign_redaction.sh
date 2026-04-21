#!/usr/bin/env bash
# check_sovereign_redaction.sh
#
# Enforce the Qinao SDK's "control plane public, verdict machinery
# private" discipline (see dazzling-weaving-plum plan §3.2 and §6).
#
# This script emits the QinaoRuntimeSDK symbol graph and scans the
# *public* declarations across every Qinao module for forbidden
# substrate-machinery tokens. Internal verdict engines, token
# authorities, sentinels, audit ledgers, etc. are allowed to be used
# privately inside Qinao modules — they just must not appear in any
# public symbol's declaration fragment.
#
# Also scans the README (when present) for the same token set.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PKG_DIR="$ROOT/QinaoRuntimeSDK"

if [[ ! -d "$PKG_DIR" ]]; then
  echo "check_sovereign_redaction: $PKG_DIR not found" >&2
  exit 1
fi

cd "$PKG_DIR"

# Generate a fresh symbol graph so stale builds can't mask a regression.
swift package dump-symbol-graph >/tmp/qinao_symbolgraph.log 2>&1 || {
  echo "check_sovereign_redaction: symbol graph emission failed" >&2
  cat /tmp/qinao_symbolgraph.log >&2
  exit 1
}

SYMBOL_DIR="$(ls -d "$PKG_DIR"/.build/*/symbolgraph 2>/dev/null | head -n 1 || true)"
if [[ -z "$SYMBOL_DIR" ]]; then
  echo "check_sovereign_redaction: no symbolgraph directory emitted" >&2
  exit 1
fi

export SYMBOL_DIR
export README_PATH="$PKG_DIR/README.md"

python3 - <<'PY'
import glob
import json
import os
import sys

FORBIDDEN = [
    # Internal L14 modules — names must never surface in Qinao's public API.
    "IntegritySentinel",
    "VerdictEngine",
    "SovereignLockManager",
    "TokenAuthority",
    "AuditLedger",
    "ContaminationGuard",
    "PrivilegeArbiter",
    "SnapshotManager",
    "StubRenderer",
    # Decision-plane nouns and brand-internal code names.
    "BlackRing",
    "EBRAIN",
    "EBrain",
    "Verdict",
    "Sentinel",
    # Chinese internal code names from the design docs.
    "宿纹",
    "玄戒",
]

symbol_dir = os.environ["SYMBOL_DIR"]
readme_path = os.environ["README_PATH"]

violations = []

# ---- 1. Public symbol graph scan -------------------------------------
qinao_graphs = sorted(glob.glob(os.path.join(symbol_dir, "Qinao*.symbols.json")))
if not qinao_graphs:
    print("check_sovereign_redaction: no Qinao*.symbols.json found", file=sys.stderr)
    sys.exit(1)

for path in qinao_graphs:
    module = os.path.basename(path).removesuffix(".symbols.json")
    if module.endswith("PackageTests"):
        continue
    data = json.load(open(path))
    for sym in data.get("symbols", []):
        if sym.get("accessLevel") != "public":
            continue
        decl = "".join(f.get("spelling", "")
                       for f in sym.get("declarationFragments", []))
        for tok in FORBIDDEN:
            if tok in decl:
                title = sym.get("names", {}).get("title", "?")
                violations.append(
                    f"[public-api] {module}:{title} contains forbidden token "
                    f"'{tok}' in declaration:\n    {decl}")

# ---- 2. README scan --------------------------------------------------
if os.path.exists(readme_path):
    with open(readme_path, encoding="utf-8") as fh:
        for lineno, line in enumerate(fh, 1):
            for tok in FORBIDDEN + ["BehavioralAISubstrate", "BAS"]:
                if tok in line:
                    # Allow attribution-style references at most in a
                    # "License / Credits" footer. For the strict check
                    # used on QinaoRuntimeSDK/README.md, even that is
                    # forbidden — the README is the brand surface.
                    violations.append(
                        f"[readme] {readme_path}:{lineno}: contains forbidden "
                        f"token '{tok}'\n    {line.rstrip()}")

if violations:
    print("Redaction violations found (Qinao SDK public surface):",
          file=sys.stderr)
    for v in violations:
        print("  " + v, file=sys.stderr)
    sys.exit(1)

print(f"check_sovereign_redaction: clean across "
      f"{len([p for p in qinao_graphs if not p.endswith('PackageTests.symbols.json')])} "
      f"Qinao modules.")
PY
