#!/usr/bin/env python3
"""R2 pipeline — 合并去重 → sha 钉 → R1 网格提案 → J2 bootstrap 判决(协议冻结于账本第五部分)。

用法:
  b2_r2_pipeline.py merge <f1.jsonl> [f2.jsonl ...]     # 合并+按题文去重(首现胜)+sha
  b2_r2_pipeline.py propose                              # R1 12 点网格,内部验证选点
  b2_r2_pipeline.py judge                                # J2:heldout 只碰一次,配对 bootstrap

J2(冻结):certified ⇔ 配对 bootstrap(10,000 重采样,种子 20260709)ΔAUC 95% CI
下界 > 0 ∧ Δ ≥ 0.01 ∧ math/broad 域回归容差 0.01(同 J1)。基线臂 = 在位 v2 权重
(Mac 特征上拟合)在设备新 heldout 上重评——Mac→设备特征漂移会显形为在位 AUC 变化,
本身是发现;对"生产该用哪份权重"这一判据对双方公平。对照臂 = R1 被驳候选(λ=0.03×9000
旧权重文件)同场重评。
"""
import hashlib
import json
import sys

import numpy as np

CORPUS = "/tmp/gdn_coreai/b2_r2_corpus.jsonl"
CORPUS_SHA_FILE = "/tmp/gdn_coreai/b2_r2_corpus.sha"
INCUMBENT = "/tmp/gdn_coreai/probe_weights_v2.json"
R1_REJECTED = "/tmp/gdn_coreai/b2_refit_candidate_weights.json"
CAND_OUT = "/tmp/gdn_coreai/b2_r2_candidate_weights.json"
EVIDENCE_OUT = "/tmp/gdn_coreai/b2_r2_evidence.json"
JUDGE_OUT = "/tmp/gdn_coreai/b2_r2_judgement.json"

SPLIT_SEED = 20260704          # 划分法与种子同 R1(冻结)
BOOT_SEED = 20260709
BOOT_N = 10_000
LAM_GRID = [0.0001, 0.0003, 0.001, 0.003, 0.01, 0.03]
ITER_GRID = [3000, 9000]
DELTA_CERTIFY = 0.01
DOMAIN_TOL = 0.01
BROAD_FAMS = {"recall", "reading", "alpha", "reverse"}


def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def merge(*paths):
    seen = set()
    kept, dup = [], 0
    # 首现胜:half 文件内部本身按题面顺序;先 0 后 1 与生成顺序交错无妨——
    # 题文相同即同题(答案确定),first-wins 保证 v2 重生成题优先存活。
    for path in paths:
        for line in open(path):
            if not line.strip():
                continue
            r = json.loads(line)
            if r["q"] in seen:
                dup += 1
                continue
            seen.add(r["q"])
            kept.append(line.rstrip("\n"))
    with open(CORPUS, "w") as f:
        f.write("\n".join(kept) + "\n")
    sha = sha256(CORPUS)
    open(CORPUS_SHA_FILE, "w").write(sha)
    print(f"merged: kept={len(kept)} dup_dropped={dup} sha={sha}")
    rows = [json.loads(l) for l in kept]
    from collections import Counter
    print("families:", dict(Counter(r["family"] for r in rows)))
    print(f"pos_rate={sum(r['label'] for r in rows) / len(rows):.3f}")


def load():
    sha = sha256(CORPUS)
    pinned = open(CORPUS_SHA_FILE).read().strip()
    assert sha == pinned, f"corpus sha mismatch: {sha} != pinned {pinned}"
    rows = [json.loads(l) for l in open(CORPUS) if l.strip()]
    H = np.array([r["h"] for r in rows], dtype=np.float64)
    y = np.array([r["label"] for r in rows], dtype=np.float64)
    fam = [r["family"] for r in rows]
    band = np.array([r["band"] for r in rows])
    return rows, H, y, fam, band


def split(rows, y, fam, band):
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
    rows, H, y, fam, band = load()
    tr, te, rng = split(rows, y, fam, band)
    Xtr, mu, sd = standardize(H[tr])
    inner = rng.permutation(len(tr))
    cut = int(len(tr) * 0.75)
    itr, iva = inner[:cut], inner[cut:]
    grid, best = [], (None, None, -1.0)
    for lam in LAM_GRID:
        for iters in ITER_GRID:
            w, b = fit_logistic(Xtr[itr], y[tr][itr], lam, iters)
            a = auc(Xtr[iva] @ w + b, y[tr][iva])
            grid.append({"lam": lam, "iters": iters, "inner_val_auc": round(a, 4)})
            print(f"  lam={lam} iters={iters}: inner_val_auc={a:.4f}")
            if a > best[2]:
                best = (lam, iters, a)
    lam, iters, val_a = best
    print(f"R2 PROPOSAL: lam={lam} iters={iters} (inner_val={val_a:.4f})")
    w, b = fit_logistic(Xtr, y[tr], lam, iters)
    json.dump({"w": w.tolist(), "b": float(b), "mu": mu.tolist(), "sd": sd.tolist(),
               "heldout_auc": float("nan"), "lam": lam, "iters": iters,
               "n_train": int(len(tr)), "n_test": int(len(te))}, open(CAND_OUT, "w"))
    json.dump({"rule": "R1 grid on R2 corpus", "corpus_sha256": open(CORPUS_SHA_FILE).read().strip(),
               "split_seed": SPLIT_SEED, "grid": grid,
               "chosen": {"lam": lam, "iters": iters, "inner_val_auc": round(val_a, 4)}},
              open(EVIDENCE_OUT, "w"), indent=1)
    print(f"candidate → {CAND_OUT}")


def judge():
    rows, H, y, fam, band = load()
    tr, te, _ = split(rows, y, fam, band)
    fam_te = [fam[i] for i in te]
    inc = json.load(open(INCUMBENT))
    cand = json.load(open(CAND_OUT))
    r1_rej = json.load(open(R1_REJECTED)) if __import__("os").path.exists(R1_REJECTED) else None

    def scores(wj):
        return ((H[te] - np.array(wj["mu"])) / np.array(wj["sd"])) @ np.array(wj["w"]) + wj["b"]

    si, sc = scores(inc), scores(cand)
    yte = y[te]

    def domain_auc(s, keep_broad):
        keep = [i for i, f in enumerate(fam_te) if (f in BROAD_FAMS) == keep_broad]
        return auc(s[keep], yte[keep]) if keep else float("nan")

    inc_auc, cand_auc = auc(si, yte), auc(sc, yte)
    # 配对 bootstrap(同一重采样下标同时作用双臂 = 配对)
    brng = np.random.default_rng(BOOT_SEED)
    n = len(te)
    deltas = np.empty(BOOT_N)
    for i in range(BOOT_N):
        idx = brng.integers(0, n, n)
        deltas[i] = auc(sc[idx], yte[idx]) - auc(si[idx], yte[idx])
    lo, hi = np.percentile(deltas, [2.5, 97.5])
    delta = cand_auc - inc_auc
    inc_math, inc_broad = domain_auc(si, False), domain_auc(si, True)
    cand_math, cand_broad = domain_auc(sc, False), domain_auc(sc, True)
    certified = (lo > 0 and delta >= DELTA_CERTIFY
                 and cand_math >= inc_math - DOMAIN_TOL
                 and cand_broad >= inc_broad - DOMAIN_TOL)
    out = {"rule": "J2 (paired bootstrap, RSI charter part 5 R2)",
           "corpus": {"sha256": open(CORPUS_SHA_FILE).read().strip(), "n": len(rows),
                      "n_test": int(len(te))},
           "incumbent_on_device_heldout": {"auc": round(inc_auc, 4), "math": round(inc_math, 4),
                                           "broad": round(inc_broad, 4),
                                           "note": "Mac-fit weights on device features — drift shows here"},
           "candidate": {"auc": round(cand_auc, 4), "math": round(cand_math, 4),
                         "broad": round(cand_broad, 4), "lam": cand["lam"], "iters": cand["iters"]},
           "paired_bootstrap": {"n_resamples": BOOT_N, "seed": BOOT_SEED,
                                "delta": round(delta, 4), "ci95": [round(lo, 4), round(hi, 4)]},
           "criteria": {"ci_lower_gt_zero": bool(lo > 0), "delta_ge": DELTA_CERTIFY,
                        "domain_tol": DOMAIN_TOL},
           "verdict": "CERTIFIED" if certified else "REJECTED"}
    if r1_rej is not None:
        sr = scores(r1_rej)
        out["r1_rejected_comparison_arm"] = {
            "auc": round(auc(sr, yte), 4),
            "math": round(domain_auc(sr, False), 4), "broad": round(domain_auc(sr, True), 4)}
    json.dump(out, open(JUDGE_OUT, "w"), indent=1)
    print(json.dumps(out, indent=1, ensure_ascii=False))


def _strat_boot_delta(sc, si, y_sub, n_boot, seed):
    """类别保持(分层)配对 bootstrap;退化不可能(每类各自重采样)。"""
    pos = np.where(y_sub == 1)[0]
    neg = np.where(y_sub == 0)[0]
    if len(pos) == 0 or len(neg) == 0:
        return None
    rng = np.random.default_rng(seed)
    deltas = np.empty(n_boot)
    for k in range(n_boot):
        b = np.concatenate([pos[rng.integers(0, len(pos), len(pos))],
                            neg[rng.integers(0, len(neg), len(neg))]])
        deltas[k] = auc(sc[b], y_sub[b]) - auc(si[b], y_sub[b])
    lo, hi = np.percentile(deltas, [2.5, 97.5])
    return [round(float(lo), 4), round(float(hi), 4)]


def describe3():
    """R3 修订1:描述性轮——三臂分域 AUC 表,无 verdict,无采纳通道。"""
    sha = sha256(FRESH)
    assert sha == open(FRESH_SHA_FILE).read().strip(), "fresh sha mismatch"
    rows = [json.loads(l) for l in open(FRESH) if l.strip()]
    H = np.array([r["h"] for r in rows], dtype=np.float64)
    y = np.array([r["label"] for r in rows], dtype=np.float64)
    fam = [r["family"] for r in rows]
    arms = {}
    for name, (path, pin) in PIN.items():
        actual = sha256(path)[:16]
        assert actual == pin, f"{name} sha mismatch: {actual} != pinned {pin}"
        wj = json.load(open(path))
        arms[name] = ((H - np.array(wj["mu"])) / np.array(wj["sd"])) @ np.array(wj["w"]) + wj["b"]
    from collections import Counter
    fam_n = Counter(fam)
    domains = {"overall": list(range(len(rows)))}
    for f in sorted(fam_n):
        domains[f] = [i for i, x in enumerate(fam) if x == f]
    out = {"rule": "R3-DESCRIPTIVE (修订1,无 verdict 无采纳通道;R2 发现维持 UNPROVEN)",
           "fresh": {"sha256": sha, "n": len(rows),
                     "families": {k: int(v) for k, v in fam_n.items()},
                     "pos_rate": round(float(y.mean()), 3)},
           "arm_shas": {k: sha256(p)[:16] for k, (p, _) in PIN.items()},
           "domains": {}}
    sc, si = arms["r2_candidate"], arms["incumbent"]
    for dname, idx in domains.items():
        idx = np.array(idx)
        ys = y[idx]
        entry = {"n": int(len(idx)), "n_neg": int((ys == 0).sum())}
        for name, s_arm in arms.items():
            a = auc(s_arm[idx], ys)
            entry[name] = round(a, 4) if a == a else None
        ci = _strat_boot_delta(sc[idx], si[idx], ys, BOOT_N, J3_BOOT_SEED)
        entry["delta_cand_vs_inc_ci95_strat"] = ci
        out["domains"][dname] = entry
    json.dump(out, open("/tmp/gdn_coreai/b2_r3_descriptive.json", "w"), indent=1)
    print(json.dumps(out, indent=1, ensure_ascii=False))


R4_FRESH = "/tmp/gdn_coreai/b2_r4_fresh.jsonl"
R4_SHA_FILE = "/tmp/gdn_coreai/b2_r4_fresh.sha"
R4_OUT = "/tmp/gdn_coreai/b2_r4_judgement.json"
R4_BOOT_SEED = 20260718


def merge_r4(*paths):
    """R4 合并:语义键内部去重 + 对 1171 语料与 R3 fresh 双集排除。"""
    excl = {semantic_key(json.loads(l)) for l in open(CORPUS) if l.strip()}
    import os
    if os.path.exists(FRESH):
        excl |= {semantic_key(json.loads(l)) for l in open(FRESH) if l.strip()}
    seen, kept, dup, leaked = set(), [], 0, 0
    for path in paths:
        for line in open(path):
            if not line.strip():
                continue
            r = json.loads(line)
            k = semantic_key(r)
            if k in excl:
                leaked += 1
                continue
            if k in seen:
                dup += 1
                continue
            seen.add(k)
            kept.append(line.rstrip("\n"))
    with open(R4_FRESH, "w") as f:
        f.write("\n".join(kept) + "\n")
    open(R4_SHA_FILE, "w").write(sha256(R4_FRESH))
    rows = [json.loads(l) for l in kept]
    from collections import Counter
    print(f"r4-fresh: kept={len(kept)} dup={dup} excluded={leaked}")
    print("families:", dict(Counter(r["family"] for r in rows)))
    for f in sorted(set(r["family"] for r in rows)):
        sub = [r for r in rows if r["family"] == f]
        print(f"  {f}: n={len(sub)} neg={sum(1 for r in sub if r['label'] == 0)}")


def judge4():
    """J4(章程第六部分,冻结):纯确认——alpha 主门 + math 非劣 + overall 守卫。"""
    sha = sha256(R4_FRESH)
    assert sha == open(R4_SHA_FILE).read().strip(), "r4 fresh sha mismatch"
    rows = [json.loads(l) for l in open(R4_FRESH) if l.strip()]
    H = np.array([r["h"] for r in rows], dtype=np.float64)
    y = np.array([r["label"] for r in rows], dtype=np.float64)
    fam = [r["family"] for r in rows]
    arms = {}
    for name, (path, pin) in PIN.items():
        actual = sha256(path)[:16]
        assert actual == pin, f"{name} sha mismatch: {actual} != pinned {pin}"
        wj = json.load(open(path))
        arms[name] = ((H - np.array(wj["mu"])) / np.array(wj["sd"])) @ np.array(wj["w"]) + wj["b"]
    sc, si = arms["r2_candidate"], arms["incumbent"]

    def dom(name_filter):
        return np.array([i for i, f in enumerate(fam) if name_filter(f)])

    def block(idx):
        ys = y[idx]
        a_c, a_i = auc(sc[idx], ys), auc(si[idx], ys)
        ci = _strat_boot_delta(sc[idx], si[idx], ys, BOOT_N, R4_BOOT_SEED)
        return {"n": int(len(idx)), "n_neg": int((ys == 0).sum()),
                "inc": round(a_i, 4) if a_i == a_i else None,
                "cand": round(a_c, 4) if a_c == a_c else None,
                "delta": round(a_c - a_i, 4) if a_c == a_c and a_i == a_i else None,
                "ci95_strat": ci}

    alpha = block(dom(lambda f: f == "alpha"))
    math_ = block(dom(lambda f: f not in BROAD_FAMS and f != "elements"))
    overall = block(dom(lambda f: True))
    desc = {f: block(dom(lambda x, f=f: x == f)) for f in ("reverse", "elements")}
    underpowered = alpha["n_neg"] < 60
    crit = {"alpha_n_neg_ge_60": not underpowered,
            "alpha_ci_lo_gt_0": bool(alpha["ci95_strat"] and alpha["ci95_strat"][0] > 0),
            "alpha_delta_ge_0.10": bool(alpha["delta"] is not None and alpha["delta"] >= 0.10),
            "math_noninferior_ci_lo_gt_-0.03": bool(math_["ci95_strat"] and math_["ci95_strat"][0] > -0.03),
            "overall_ci_lo_gt_-0.02": bool(overall["ci95_strat"] and overall["ci95_strat"][0] > -0.02)}
    verdict = ("UNDERPOWERED-DESCRIPTIVE" if underpowered
               else "CERTIFIED" if all(crit.values()) else "REJECTED")
    out = {"rule": "J4 (charter part 6, pure confirmation on new banks)",
           "fresh": {"sha256": sha, "n": len(rows)},
           "arm_shas": {k: sha256(p)[:16] for k, (p, _) in PIN.items()},
           "attempt_history": "第 3 次判决尝试(R1 人驳/R2 J2 驳/R4)——多重比较注记",
           "alpha_primary": alpha, "math_guard": math_, "overall_guard": overall,
           "descriptive": desc, "criteria": crit, "verdict": verdict}
    json.dump(out, open(R4_OUT, "w"), indent=1)
    print(json.dumps(out, indent=1, ensure_ascii=False))


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else ""
    if cmd == "merge":
        merge(*sys.argv[2:])
    elif cmd == "merge-fresh":
        merge_fresh(*sys.argv[2:])
    elif cmd == "judge3":
        judge3()
    elif cmd == "describe3":
        describe3()
    elif cmd == "merge-r4":
        merge_r4(*sys.argv[2:])
    elif cmd == "judge4":
        judge4()
    elif cmd == "propose":
        propose()
    elif cmd == "judge":
        judge()
    else:
        print(__doc__)


# ── R3 / J3(域级判据,确认性检验;预注册见账本 R3 节)─────────────────────────
FRESH = "/tmp/gdn_coreai/b2_r3_fresh.jsonl"
FRESH_SHA_FILE = "/tmp/gdn_coreai/b2_r3_fresh.sha"
J3_OUT = "/tmp/gdn_coreai/b2_r3_judgement.json"
J3_BOOT_SEED = 20260715
PIN = {  # 三臂文件 sha256 前缀,冻结于新数据之前(账本 R3 节)——judge3 强制校验
    "incumbent": ("/tmp/gdn_coreai/probe_weights_v2.json", "cf8276421e5d12bf"),
    "r1_rejected": ("/tmp/gdn_coreai/b2_refit_candidate_weights.json", "2eac90211acaae7d"),
    "r2_candidate": ("/tmp/gdn_coreai/b2_r2_candidate_weights.json", "1aa86c252a7415fa"),
}


def semantic_key(r):
    """R3 修订2:排除键 = 语义键(alpha 三词排序/recall 国家/reverse 词;其余题文)。
    封死 Swift Set 迭代序造成的 alpha 换序马甲泄漏;recall/reverse 语义重复正确判已知。"""
    q, fam = r["q"], r["family"]
    if fam == "alpha":
        try:
            words = q.split(": ", 1)[1].split("? Answer")[0].split(", ")
            return ("alpha", tuple(sorted(w.strip() for w in words)))
        except IndexError:
            return ("alpha", q)
    if fam == "recall":
        return ("recall", q.split("capital city of ", 1)[-1].split("?")[0].strip())
    if fam == "reverse":
        try:
            return ("reverse", q.split('"')[1])
        except IndexError:
            return ("reverse", q)
    return (fam, q)


def merge_fresh(*paths):
    """新 heldout 合并:内部去重 + 对 1171 训练语料【按语义键排除】(泄漏防线,修订2)。"""
    corpus_keys = {semantic_key(json.loads(l)) for l in open(CORPUS) if l.strip()}
    seen, kept, dup, leaked = set(), [], 0, 0
    for path in paths:
        for line in open(path):
            if not line.strip():
                continue
            r = json.loads(line)
            k = semantic_key(r)
            if k in corpus_keys:
                leaked += 1
                continue
            if k in seen:
                dup += 1
                continue
            seen.add(k)
            kept.append(line.rstrip("\n"))
    with open(FRESH, "w") as f:
        f.write("\n".join(kept) + "\n")
    sha = sha256(FRESH)
    open(FRESH_SHA_FILE, "w").write(sha)
    rows = [json.loads(l) for l in kept]
    from collections import Counter
    print(f"fresh: kept={len(kept)} dup={dup} excluded_in_corpus={leaked} sha={sha}")
    print("families:", dict(Counter(r["family"] for r in rows)))
    print(f"pos_rate={sum(r['label'] for r in rows) / len(rows):.3f}")


def judge3():
    sha = sha256(FRESH)
    assert sha == open(FRESH_SHA_FILE).read().strip(), "fresh sha mismatch"
    rows = [json.loads(l) for l in open(FRESH) if l.strip()]
    H = np.array([r["h"] for r in rows], dtype=np.float64)
    y = np.array([r["label"] for r in rows], dtype=np.float64)
    fam = [r["family"] for r in rows]
    arms = {}
    for name, (path, pin) in PIN.items():
        actual = sha256(path)[:16]
        assert actual == pin, f"{name} sha mismatch: {actual} != pinned {pin}(臂文件被动过,判决拒开)"
        wj = json.load(open(path))
        arms[name] = ((H - np.array(wj["mu"])) / np.array(wj["sd"])) @ np.array(wj["w"]) + wj["b"]
    broad_idx = [i for i, f in enumerate(fam) if f in BROAD_FAMS]
    math_idx = [i for i, f in enumerate(fam) if f not in BROAD_FAMS]

    def boot_delta(sc, si, idx):
        idx = np.array(idx)
        a_c, a_i = auc(sc[idx], y[idx]), auc(si[idx], y[idx])
        rng = np.random.default_rng(J3_BOOT_SEED)
        deltas = np.empty(BOOT_N)
        for k in range(BOOT_N):
            b = idx[rng.integers(0, len(idx), len(idx))]
            deltas[k] = auc(sc[b], y[b]) - auc(si[b], y[b])
        lo, hi = np.percentile(deltas, [2.5, 97.5])
        return {"cand": round(a_c, 4), "inc": round(a_i, 4),
                "delta": round(a_c - a_i, 4), "ci95": [round(lo, 4), round(hi, 4)]}

    sc, si = arms["r2_candidate"], arms["incumbent"]
    broad = boot_delta(sc, si, broad_idx)
    math_ = boot_delta(sc, si, math_idx)
    overall = boot_delta(sc, si, list(range(len(rows))))
    crit = {"broad_ci_lo_gt_0": broad["ci95"][0] > 0,
            "broad_delta_ge_0.05": broad["delta"] >= 0.05,
            "math_noninferior_ci_lo_gt_-0.03": math_["ci95"][0] > -0.03,
            "overall_ci_lo_gt_-0.02": overall["ci95"][0] > -0.02}
    verdict = "CERTIFIED" if all(crit.values()) else "REJECTED"
    sr = arms["r1_rejected"]
    out = {"rule": "J3 (domain-level paired bootstrap, charter R3)",
           "fresh": {"sha256": sha, "n": len(rows), "n_broad": len(broad_idx),
                     "n_math": len(math_idx)},
           "arm_shas": {k: sha256(p)[:16] for k, (p, _) in PIN.items()},
           "broad_reading_proxy": broad, "math": math_, "overall": overall,
           "r1_rejected_context": {"broad": round(auc(sr[broad_idx], y[broad_idx]), 4),
                                   "math": round(auc(sr[math_idx], y[math_idx]), 4)},
           "criteria": crit, "verdict": verdict}
    json.dump(out, open(J3_OUT, "w"), indent=1)
    print(json.dumps(out, indent=1, ensure_ascii=False))
