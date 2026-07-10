"""B2 tail-closure — v1 difficulty-probe OUT-OF-DOMAIN evaluation.

The v1 probe (Docs/probe_weights_v1_2026-07-04.json, held-out AUC 0.833) was trained on 7
math/counting families only. This scores it on the 4 BROAD families (recall / reading /
alpha / reverse; collected by testCollectBroadProbeFeatures) and answers, per family and
pooled: (a) does the ranking generalize (AUC)? (b) is the CALIBRATION safe for the production
act-band (act only outside p∈[0.35, 0.85])? — i.e. what fraction of wrong-answer prompts
would be confidently DOWNSHIFTED (p>0.85) and right-answer prompts confidently UPSHIFTED.

Verdict rule (recorded in FRONTIER_2026H2_EVOLUTION.md): v1 generalizes iff pooled OOD
AUC ≥ 0.70 and the p>0.85 bucket's realized success ≥ the in-domain equivalent; otherwise
ship a v2 refit on the combined set.
"""
import json
import math
import os
import sys
from collections import defaultdict

# audit tools-scripts / decision 7: resolve WEIGHTS relative to THIS file, not the cwd, so the script
# runs from any directory (matching the absolute-path convention of sibling Tools scripts).
_REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WEIGHTS = os.path.join(_REPO_ROOT, "Docs", "probe_weights_v1_2026-07-04.json")
BROAD = "/tmp/gdn_coreai/probe_features_broad.jsonl"

# audit tools-scripts / decision 7: the in-domain downshift-bucket success floor the OOD verdict
# compares against (was an inline 0.85). Named so the verdict rule is grep-able + tunable in one place.
IN_DOMAIN_DOWNSHIFT_SUCCESS = 0.85


def auc(scores: list[float], labels: list[int]) -> float:
    pairs = sorted(zip(scores, labels))
    pos = sum(labels)
    neg = len(labels) - pos
    if pos == 0 or neg == 0:
        return float("nan")
    rank_sum = 0.0
    i = 0
    while i < len(pairs):
        j = i
        while j < len(pairs) and pairs[j][0] == pairs[i][0]:
            j += 1
        avg_rank = (i + j + 1) / 2.0
        rank_sum += sum(avg_rank for k in range(i, j) if pairs[k][1] == 1)
        i = j
    return (rank_sum - pos * (pos + 1) / 2.0) / (pos * neg)


def main() -> None:
    wj = json.load(open(WEIGHTS))
    w, b, mu, sd = wj["w"], wj["b"], wj["mu"], wj["sd"]
    rows = [json.loads(line) for line in open(BROAD)]
    if not rows:
        sys.exit("no broad rows collected")
    by_fam: dict[str, list[tuple[float, int]]] = defaultdict(list)
    for r in rows:
        z = sum(wi * (hi - m) / s for wi, hi, m, s in zip(w, r["h"], mu, sd)) + b
        p = 1.0 / (1.0 + math.exp(-z))
        by_fam[r["family"]].append((p, r["label"]))
    pooled: list[tuple[float, int]] = []
    print(f"{'family':8s} {'n':>3s} {'acc':>5s} {'AUC':>5s}  p>0.85: n/succ   p<0.35: n/succ")
    for fam, sl in sorted(by_fam.items()):
        pooled += sl
        ps, ls = [p for p, _ in sl], [l for _, l in sl]
        hi = [l for p, l in sl if p > 0.85]
        lo = [l for p, l in sl if p < 0.35]
        print(f"{fam:8s} {len(sl):3d} {sum(ls)/len(ls):5.2f} {auc(ps, ls):5.2f}  "
              f"{len(hi):2d}/{(sum(hi)/len(hi)) if hi else float('nan'):4.2f}      "
              f"{len(lo):2d}/{(sum(lo)/len(lo)) if lo else float('nan'):4.2f}")
    ps, ls = [p for p, _ in pooled], [l for _, l in pooled]
    hi = [l for p, l in pooled if p > 0.85]
    lo = [l for p, l in pooled if p < 0.35]
    mid = [l for p, l in pooled if 0.35 <= p <= 0.85]
    print(f"{'POOLED':8s} {len(pooled):3d} {sum(ls)/len(ls):5.2f} {auc(ps, ls):5.2f}  "
          f"{len(hi):2d}/{(sum(hi)/len(hi)) if hi else float('nan'):4.2f}      "
          f"{len(lo):2d}/{(sum(lo)/len(lo)) if lo else float('nan'):4.2f}"
          f"   mid-band(no-op): {len(mid)}/{(sum(mid)/len(mid)) if mid else float('nan'):4.2f}")
    pooled_auc = auc(ps, ls)
    hi_succ = (sum(hi) / len(hi)) if hi else float("nan")
    verdict = "GENERALIZES" if (pooled_auc >= 0.70 and (not hi or hi_succ >= IN_DOMAIN_DOWNSHIFT_SUCCESS)) \
        else "NEEDS v2 REFIT"
    print(f"\nVERDICT: v1 {verdict} (pooled OOD AUC={pooled_auc:.3f}, "
          f"downshift-bucket success={hi_succ:.2f})")


if __name__ == "__main__":
    main()
