#!/usr/bin/env python3
"""B2 difficulty-probe fit — numpy-only L2 logistic on last-prompt-token hidden states.

Rigor: 70/30 split STRATIFIED by (family, band); held-out AUC reported for
(a) the hidden-state probe, (b) a qlen-only baseline (the paper's 0.754-class control),
(c) a family-onehot baseline (does the probe beat 'just knowing the question type'?).
n≈147 vs d=4096 ⇒ heavy L2 swept on a small validation slice of TRAIN only.
"""
import json, sys, math
import numpy as np

path = sys.argv[1] if len(sys.argv) > 1 else "/tmp/gdn_coreai/probe_features.jsonl"
out = sys.argv[2] if len(sys.argv) > 2 else "/tmp/gdn_coreai/probe_weights.json"

rows = [json.loads(l) for l in open(path) if l.strip()]
H = np.array([r["h"] for r in rows], dtype=np.float64)
y = np.array([r["label"] for r in rows], dtype=np.float64)
qlen = np.array([r["qlen"] for r in rows], dtype=np.float64)
fam = [r["family"] for r in rows]
band = np.array([r["band"] for r in rows])
print(f"n={len(rows)} d={H.shape[1]} pos_rate={y.mean():.3f}")
for f in sorted(set(fam)):
    m = np.array([x == f for x in fam])
    print(f"  {f}: n={m.sum()} acc={y[m].mean():.2f} by_band=" +
          ",".join(f"{y[m & (band==b)].mean():.2f}" for b in range(3)))

# stratified split by (family, band, label) with fixed rng
rng = np.random.default_rng(20260704)
tr_idx, te_idx = [], []
for key in sorted(set(zip(fam, band.tolist(), y.tolist()))):
    idx = [i for i in range(len(rows)) if (fam[i], band[i], y[i]) == key]
    idx = list(rng.permutation(idx))
    k = max(1, int(round(len(idx) * 0.3)))
    te_idx += idx[:k]; tr_idx += idx[k:]
tr, te = np.array(tr_idx), np.array(te_idx)
print(f"train={len(tr)} test={len(te)} test_pos={y[te].mean():.2f}")

def standardize(X, mu=None, sd=None):
    if mu is None:
        mu = X.mean(0); sd = X.std(0) + 1e-8
    return (X - mu) / sd, mu, sd

def fit_logistic(X, t, lam, iters=3000, lr=0.05):
    w = np.zeros(X.shape[1]); b = 0.0
    for _ in range(iters):
        p = 1 / (1 + np.exp(-(X @ w + b)))
        g = X.T @ (p - t) / len(t) + lam * w
        gb = (p - t).mean()
        w -= lr * g; b -= lr * gb
    return w, b

def auc(scores, labels):
    order = np.argsort(scores)
    ranks = np.empty(len(scores)); ranks[order] = np.arange(1, len(scores) + 1)
    pos = labels == 1
    n1, n0 = pos.sum(), (~pos).sum()
    if n1 == 0 or n0 == 0: return float("nan")
    return (ranks[pos].sum() - n1 * (n1 + 1) / 2) / (n1 * n0)

Xtr_raw, Xte_raw = H[tr], H[te]
Xtr, mu, sd = standardize(Xtr_raw)
Xte, _, _ = standardize(Xte_raw, mu, sd)

# λ sweep on an inner split of TRAIN only
inner = rng.permutation(len(tr)); cut = int(len(tr) * 0.75)
itr, iva = inner[:cut], inner[cut:]
best = (None, -1)
for lam in [0.003, 0.01, 0.03, 0.1, 0.3, 1.0]:
    w, b = fit_logistic(Xtr[itr], y[tr][itr], lam)
    a = auc(Xtr[iva] @ w + b, y[tr][iva])
    print(f"  lam={lam}: inner_auc={a:.3f}")
    if a > best[1]: best = (lam, a)
lam = best[0]
w, b = fit_logistic(Xtr, y[tr], lam)
probe_auc = auc(Xte @ w + b, y[te])

# baselines
ql_tr = (qlen[tr] - qlen[tr].mean()) / (qlen[tr].std() + 1e-8)
ql_te = (qlen[te] - qlen[tr].mean()) / (qlen[tr].std() + 1e-8)
wq, bq = fit_logistic(ql_tr.reshape(-1, 1), y[tr], 0.01)
len_auc = auc(ql_te * wq[0] + bq, y[te])
fams = sorted(set(fam))
F = np.array([[1.0 if fam[i] == f else 0.0 for f in fams] + [band[i] / 2] for i in range(len(rows))])
wf, bf = fit_logistic(F[tr], y[tr], 0.01)
fam_auc = auc(F[te] @ wf + bf, y[te])

print(f"\nHELD-OUT AUC: probe={probe_auc:.3f} | qlen-baseline={len_auc:.3f} | family+band-baseline={fam_auc:.3f} (lam={lam})")

# per-domain held-out AUC (v2 acceptance: broad must become rankable WITHOUT in-domain regression)
BROAD_FAMS = {"recall", "reading", "alpha", "reverse"}
te_scores = Xte @ w + b
for name, keep in (("math", [i for i, t in enumerate(te) if fam[t] not in BROAD_FAMS]),
                   ("broad", [i for i, t in enumerate(te) if fam[t] in BROAD_FAMS])):
    if keep:
        a = auc(te_scores[keep], y[te][keep])
        n_pos = int(y[te][keep].sum())
        print(f"  held-out {name}: n={len(keep)} pos={n_pos} auc={a:.3f}")

json.dump({"w": w.tolist(), "b": float(b), "mu": mu.tolist(), "sd": sd.tolist(),
           "heldout_auc": probe_auc, "len_auc": len_auc, "fam_auc": fam_auc,
           "lam": lam, "n_train": int(len(tr)), "n_test": int(len(te))},
          open(out, "w"))
print(f"weights → {out}")
