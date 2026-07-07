#!/usr/bin/env python3
"""暗点1 B2 refit 最小闭环 — 机器提案端(规则 R1,预注册于 RSI_IMPLANT_CHARTER 第五部分)。

本脚本 = 环路里的【机器】。它只做两件被冻结规则允许的事:
  1. PROPOSE:在预注册网格上按在位管线同法拟合,只用 TRAIN 内部验证片选点,产出候选权重+全表证据;
  2. JUDGE(--judge):heldout 只评一次——先复现在位锚(±0.002),再按 J1 判 certified/rejected。
它没有的东西:采纳权(FSM 走 Swift 侧 BASImprovementCandidate,签名在人)。
确定性:与在位完全同种子(20260704)同划分;提案空间含在位点 ⇒ 机器可自证"不改"。
"""
import hashlib
import json
import sys

import numpy as np

DATA = "/tmp/gdn_coreai/probe_features_v2.jsonl"
INCUMBENT = "/tmp/gdn_coreai/probe_weights_v2.json"
CAND_OUT = "/tmp/gdn_coreai/b2_refit_candidate_weights.json"
EVIDENCE_OUT = "/tmp/gdn_coreai/b2_refit_evidence.json"
JUDGE_OUT = "/tmp/gdn_coreai/b2_refit_judgement.json"

# ── 预注册常量(与账本逐字一致,改这里 = 违registration)────────────────────────
DATA_SHA_PINNED = "e7b49b9547045cc75794baef0adf7b924219beafbc6e380fa933bda713cde673"
SPLIT_SEED = 20260704
LAM_GRID = [0.0001, 0.0003, 0.001, 0.003, 0.01, 0.03]
ITER_GRID = [3000, 9000]
ANCHOR_TOL = 0.002
DELTA_CERTIFY = 0.01
DOMAIN_REGRESSION_TOL = 0.01
BROAD_FAMS = {"recall", "reading", "alpha", "reverse"}


def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def load_rows():
    actual = sha256(DATA)
    assert actual == DATA_SHA_PINNED, f"dataset sha mismatch: {actual} (预注册 {DATA_SHA_PINNED})"
    rows = [json.loads(l) for l in open(DATA) if l.strip()]
    H = np.array([r["h"] for r in rows], dtype=np.float64)
    y = np.array([r["label"] for r in rows], dtype=np.float64)
    fam = [r["family"] for r in rows]
    band = np.array([r["band"] for r in rows])
    return rows, H, y, fam, band


def split(rows, y, fam, band):
    # 与 fit_difficulty_probe.py 逐字同法同种子 ⇒ heldout 与在位 heldout 同一。
    rng = np.random.default_rng(SPLIT_SEED)
    tr_idx, te_idx = [], []
    for key in sorted(set(zip(fam, band.tolist(), y.tolist()))):
        idx = [i for i in range(len(rows)) if (fam[i], band[i], y[i]) == key]
        idx = list(rng.permutation(idx))
        k = max(1, int(round(len(idx) * 0.3)))
        te_idx += idx[:k]
        tr_idx += idx[k:]
    return np.array(tr_idx), np.array(te_idx), rng


def standardize(X, mu=None, sd=None):
    if mu is None:
        mu = X.mean(0)
        sd = X.std(0) + 1e-8
    return (X - mu) / sd, mu, sd


def fit_logistic(X, t, lam, iters, lr=0.05):
    w = np.zeros(X.shape[1])
    b = 0.0
    for _ in range(iters):
        p = 1 / (1 + np.exp(-(X @ w + b)))
        g = X.T @ (p - t) / len(t) + lam * w
        gb = (p - t).mean()
        w -= lr * g
        b -= lr * gb
    return w, b


def auc(scores, labels):
    order = np.argsort(scores)
    ranks = np.empty(len(scores))
    ranks[order] = np.arange(1, len(scores) + 1)
    pos = labels == 1
    n1, n0 = pos.sum(), (~pos).sum()
    if n1 == 0 or n0 == 0:
        return float("nan")
    return float((ranks[pos].sum() - n1 * (n1 + 1) / 2) / (n1 * n0))


def propose():
    rows, H, y, fam, band = load_rows()
    tr, te, rng = split(rows, y, fam, band)
    Xtr, mu, sd = standardize(H[tr])
    # inner split:与在位管线同法(rng 状态已被 split 消耗到同一点)。
    inner = rng.permutation(len(tr))
    cut = int(len(tr) * 0.75)
    itr, iva = inner[:cut], inner[cut:]
    grid = []
    best = (None, None, -1.0)
    for lam in LAM_GRID:
        for iters in ITER_GRID:
            w, b = fit_logistic(Xtr[itr], y[tr][itr], lam, iters)
            a = auc(Xtr[iva] @ w + b, y[tr][iva])
            grid.append({"lam": lam, "iters": iters, "inner_val_auc": round(a, 4)})
            print(f"  lam={lam} iters={iters}: inner_val_auc={a:.4f}")
            if a > best[2]:
                best = (lam, iters, a)
    lam, iters, val_a = best
    print(f"PROPOSAL: lam={lam} iters={iters} (inner_val_auc={val_a:.4f})")
    w, b = fit_logistic(Xtr, y[tr], lam, iters)
    json.dump({"w": w.tolist(), "b": float(b), "mu": mu.tolist(), "sd": sd.tolist(),
               "heldout_auc": float("nan"),   # 提案端不许知道 heldout——judge 填
               "lam": lam, "iters": iters,
               "n_train": int(len(tr)), "n_test": int(len(te))},
              open(CAND_OUT, "w"))
    json.dump({"rule": "R1 (RSI_IMPLANT_CHARTER 第五部分)", "dataset_sha256": DATA_SHA_PINNED,
               "split_seed": SPLIT_SEED, "grid": grid,
               "chosen": {"lam": lam, "iters": iters, "inner_val_auc": round(val_a, 4)},
               "incumbent_point_in_grid": {"lam": 0.003, "iters": 3000},
               "candidate_out": CAND_OUT},
              open(EVIDENCE_OUT, "w"), indent=1)
    print(f"candidate → {CAND_OUT}\nevidence → {EVIDENCE_OUT}")


def domain_auc(scores, labels, fam_te, keep_broad):
    keep = [i for i, f in enumerate(fam_te) if (f in BROAD_FAMS) == keep_broad]
    if not keep:
        return float("nan")
    return auc(scores[keep], labels[keep])


def judge():
    rows, H, y, fam, band = load_rows()
    tr, te, _ = split(rows, y, fam, band)
    fam_te = [fam[i] for i in te]
    inc = json.load(open(INCUMBENT))
    cand = json.load(open(CAND_OUT))

    def heldout_scores(wj):
        w = np.array(wj["w"])
        mu = np.array(wj["mu"])
        sd = np.array(wj["sd"])
        return ((H[te] - mu) / sd) @ w + wj["b"]

    si, sc = heldout_scores(inc), heldout_scores(cand)
    inc_auc = auc(si, y[te])
    cand_auc = auc(sc, y[te])
    inc_math, inc_broad = domain_auc(si, y[te], fam_te, False), domain_auc(si, y[te], fam_te, True)
    cand_math, cand_broad = domain_auc(sc, y[te], fam_te, False), domain_auc(sc, y[te], fam_te, True)

    anchor_ok = abs(inc_auc - inc["heldout_auc"]) <= ANCHOR_TOL
    certified = (anchor_ok
                 and cand_auc >= inc_auc + DELTA_CERTIFY
                 and cand_math >= inc_math - DOMAIN_REGRESSION_TOL
                 and cand_broad >= inc_broad - DOMAIN_REGRESSION_TOL)
    verdict = ("INSTRUMENT-INVALID" if not anchor_ok
               else ("CERTIFIED" if certified else "REJECTED"))
    out = {"rule": "J1 (RSI_IMPLANT_CHARTER 第五部分)",
           "anchor": {"incumbent_carried": inc["heldout_auc"], "incumbent_reeval": round(inc_auc, 4),
                      "tolerance": ANCHOR_TOL, "ok": bool(anchor_ok)},
           "incumbent": {"auc": round(inc_auc, 4), "math": round(inc_math, 4), "broad": round(inc_broad, 4),
                         "sha256": sha256(INCUMBENT)},
           "candidate": {"auc": round(cand_auc, 4), "math": round(cand_math, 4), "broad": round(cand_broad, 4),
                         "lam": cand["lam"], "iters": cand["iters"], "sha256": sha256(CAND_OUT)},
           "criteria": {"delta_certify": DELTA_CERTIFY, "domain_regression_tol": DOMAIN_REGRESSION_TOL},
           "verdict": verdict}
    json.dump(out, open(JUDGE_OUT, "w"), indent=1)
    print(json.dumps(out, indent=1, ensure_ascii=False))
    print(f"judgement → {JUDGE_OUT}")


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "--judge":
        judge()
    else:
        propose()
