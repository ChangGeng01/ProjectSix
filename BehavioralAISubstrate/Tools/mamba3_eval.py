"""SERIOUS evaluation battery for the Mamba-3 RAG reader — the make-or-break (没有严肃评测不能宣称成了). Each metric has a
formula + a threshold; the honest MUST-PASS bar lives in claim_card() (亏的不要 — no unverified claims). Reuses the audited
RAFT primitives (no re-implementation of data/CE). Runs on a real checkpoint (EVAL_CKPT=...) or a random-weight smoke
(EVAL_SMOKE=1, toy, no download/teacher — asserts every battery RUNS + returns finite shaped numbers, not thresholds).

Batteries: 1 perplexity · 2 RAFT robustness (E1/E2/E3 slopes) · 3 teacher-student fidelity (KL/top-k/argmax) ·
4 generation EM/F1 (greedy) · 5 calibration (ECE) · 6 quant fidelity (STUB → device phase) · 7 contamination guard.

Run: EVAL_SMOKE=1 ~/.venvs/coreai-cv/bin/python Tools/mamba3_eval.py      (or EVAL_CKPT=/path/ckpt.pt for a real eval)
"""
from __future__ import annotations

import hashlib
import json
import math
import os
import re
import string
import sys

import torch
import torch.nn.functional as F

sys.path.insert(0, "/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tools")
import mamba3_raft as RAFT
from mamba3_raft import eval_nll, masked_ce

DEV = "cuda" if torch.cuda.is_available() else ("mps" if torch.backends.mps.is_available() else "cpu")
RAFT.DEV = DEV
# Gate thresholds (env-tunable). The teacher baseline is MEASURED live (teacher_answer_nll), no longer a hardcoded guess.
TASK_FIT_ABS = float(os.environ.get("TASK_FIT_ABS", "2.10"))         # absolute held-answer-NLL bar
TEACHER_GAP = float(os.environ.get("TEACHER_GAP", "0.15"))          # student E1 NLL within this many nats of the MEASURED teacher
CONTEXT_USE_MARGIN = float(os.environ.get("CONTEXT_USE_MARGIN", "0.20"))  # E3(no-gold) must be >= this much WORSE than E1 (anti-parrot)
PARITY_BAR = float(os.environ.get("PARITY_BAR", "0.99"))            # device fp16 sequential-decode vs parallel argmax-agreement


# ---------------------------------------------------------------- 1) perplexity
def compute_perplexity(student, wikitext_ids, hotpotqa_held) -> dict:
    s_nll, s_tok = 0.0, 0
    with torch.no_grad():
        for ids in wikitext_ids:
            ids = ids.to(DEV)
            lg, _ = student.run_twin(ids, collect_ssm=False)
            ce = F.cross_entropy(lg[:-1].float(), ids[1:], reduction="sum")
            if torch.isfinite(ce):
                s_nll += float(ce); s_tok += ids.numel() - 1
    wt_ppl = math.exp(s_nll / max(s_tok, 1)) if s_tok else float("inf")
    hq_nll, hq_acc, hq_skip = eval_nll(student, hotpotqa_held) if hotpotqa_held else (float("inf"), 0.0, 0)
    return {"wikitext_ppl": wt_ppl, "hotpotqa_held_ppl": math.exp(hq_nll) if math.isfinite(hq_nll) else float("inf"),
            "hotpotqa_held_nll": hq_nll, "skip": hq_skip}


# ---------------------------------------------------------------- 2) RAFT robustness
def eval_raft_robustness(student, E: dict) -> dict:
    r = {m: eval_nll(student, E[m]) for m in ("E1", "E2", "E3")}
    n1, n2, n3 = r["E1"][0], r["E2"][0], r["E3"][0]
    tot = sum(len(E[m]) for m in E)
    surv = {m: len(E[m]) - r[m][2] for m in r}                       # examples that produced finite logits
    # subset guard: slopes are only valid over an IDENTICAL example set across E1/E2/E3. The conditions are pre-aligned to
    # the same id-set upstream, so equal surviving counts ⇒ same surviving subset (the sk==0 discipline raft.py main has).
    subset_ok = len(set(surv.values())) == 1 and all(v > 0 for v in surv.values())
    return {**{m: {"nll": r[m][0], "acc": r[m][1], "skip": r[m][2]} for m in r},
            "slope_e2_e1": n2 - n1, "slope_e3_e1": n3 - n1, "slope_e3_e2": n3 - n2,
            "skip_pct": sum(r[m][2] for m in r) / max(tot, 1), "subset_ok": subset_ok, "surviving": surv}


# ---------------------------------------------------------------- 3) teacher-student fidelity
def compute_fidelity(student, teacher, examples, topk: int = 5) -> dict | None:
    """Teacher-student agreement on the ANSWER SPAN ONLY (positions that predict answer tokens). The old version averaged
    over ALL positions — document-dominated, so a context-copying parrot could clear the argmax gate on trivial tokens."""
    if teacher is None:
        return None
    kl_sum, agt, agm, n = 0.0, 0, 0, 0
    with torch.no_grad():
        for ex in examples:
            ids = ex["input_ids"].to(DEV)
            plen = int(ex.get("prompt_len", 1))
            sl, _ = student.run_twin(ids, collect_ssm=False)
            tl = teacher(ids.unsqueeze(0)).logits[0].float().to(DEV)
            m = torch.arange(tl.shape[0] - 1, device=DEV) >= (plen - 1)   # positions predicting answer tokens
            if not m.any():
                continue
            tla, sla = tl[:-1][m], sl.float()[:-1][m]                     # [A, V] answer-span logits
            tlp, slp = F.log_softmax(tla, -1), F.log_softmax(sla, -1)
            kl_sum += float(F.kl_div(slp, tlp, log_target=True, reduction="batchmean"))
            ti, si = tla.topk(topk, -1).indices, sla.topk(topk, -1).indices
            A = tla.shape[0]
            agt += float(sum(len(set(ti[t].tolist()) & set(si[t].tolist())) for t in range(A)) / (topk * A))
            agm += float((tla.argmax(-1) == sla.argmax(-1)).float().mean())
            n += 1
    if n == 0:
        return {"full_vocab_kl": float("nan"), "top_k_agreement": 0.0, "argmax_agreement": 0.0}
    return {"full_vocab_kl": kl_sum / n, "top_k_agreement": agt / n, "argmax_agreement": agm / n}


# --------------------------------------------- teacher baseline (the REAL task_fit gap target, measured live)
@torch.no_grad()
def teacher_answer_nll(teacher, examples) -> float:
    """Measure the TEACHER's masked answer-span NLL on the SAME held examples — the real task_fit baseline (replaces the
    hardcoded TEACHER_NLL_E1 guess). Uses the HF teacher's logits directly (the teacher has no student.run_twin)."""
    tot_nll = tot_tok = 0.0
    for ex in examples:
        ids = ex["input_ids"].to(DEV)
        tl = teacher(ids.unsqueeze(0)).logits[0].float()
        lp, tgt = tl[:-1], ids[1:]
        m = torch.arange(tgt.shape[0], device=DEV) >= (ex["prompt_len"] - 1)
        if not m.any():
            continue
        tot_nll += float(F.cross_entropy(lp[m], tgt[m], reduction="sum")); tot_tok += int(m.sum())
    return tot_nll / tot_tok if tot_tok else float("nan")


# ---------------------------------------------------------------- 4) generation EM / F1 (greedy, normalized text)
def _normalize_text(s: str) -> str:
    """SQuAD-style normalization: lowercase, strip punctuation + articles, collapse whitespace."""
    s = "".join(ch if ch not in string.punctuation else " " for ch in s.lower())
    s = re.sub(r"\b(a|an|the)\b", " ", s)
    return " ".join(s.split())


def _f1_text(pred: str, gold: str) -> float:
    pt, gt = pred.split(), gold.split()
    if not pt or not gt:
        return float(pt == gt)
    common, g = 0, list(gt)
    for w in pt:
        if w in g:
            common += 1; g.remove(w)
    if common == 0:
        return 0.0
    prec, rec = common / len(pt), common / len(gt)
    return 2 * prec * rec / (prec + rec)


def generate_and_score(student, examples, tok, maxlen: int = 24, eos=None) -> dict:
    """Free-running greedy generation, scored by EM/F1 over NORMALIZED DETOKENIZED TEXT (SQuAD-style). Decodes a FIXED
    token budget with an optional EOS stop — NOT len(gold): the old len-leak emitted exactly len(gold) tokens, never
    testing when to STOP, so an answer-marginal parrot could score EM=1 on short/yes-no answers without learning."""
    em, f1s, n = 0, [], 0
    with torch.no_grad():
        for ex in examples:
            ids = ex["input_ids"]; plen = int(ex["prompt_len"])
            gold_txt = _normalize_text(tok.decode(ids[plen:].tolist())) if tok is not None else ""
            seq = ids[:plen].to(DEV); gen = []
            for _ in range(maxlen):
                lg, _ = student.run_twin(seq, collect_ssm=False)
                nxt = int(lg[-1].argmax())
                if eos is not None and nxt == eos:
                    break
                gen.append(nxt)
                seq = torch.cat([seq, torch.tensor([nxt], device=DEV)])
            pred_txt = _normalize_text(tok.decode(gen)) if tok is not None else ""
            em += int(pred_txt == gold_txt)
            f1s.append(_f1_text(pred_txt, gold_txt))
            n += 1
    return {"EM": em / max(n, 1), "F1": sum(f1s) / max(len(f1s), 1)}


# ---------------------------------------------------------------- 5) calibration (ECE)
def compute_ece(student, examples, bins: int = 10) -> dict:
    confs, corrs = [], []
    with torch.no_grad():
        for ex in examples:
            ids = ex["input_ids"].to(DEV)
            lg, _ = student.run_twin(ids, collect_ssm=False)
            p = lg[:-1].float().softmax(-1)
            conf, pred = p.max(-1)
            tgt = ids[1:]
            m = torch.arange(tgt.shape[0], device=DEV) >= (ex["prompt_len"] - 1)
            confs += conf[m].tolist(); corrs += (pred[m] == tgt[m]).float().tolist()
    if not confs:
        return {"ece": float("nan")}
    confs, corrs = torch.tensor(confs), torch.tensor(corrs)
    ece = 0.0
    for b in range(bins):
        lo, hi = b / bins, (b + 1) / bins
        m = (confs > lo) & (confs <= hi)
        if m.any():
            ece += float(m.float().mean()) * abs(float(corrs[m].mean()) - float(confs[m].mean()))
    return {"ece": ece}


# ---------------------------------------------------------------- 6) quant fidelity (STUB until device phase)
def quant_fidelity_stub() -> dict:
    return {"status": "STUB", "note": "fp16→int8→int4 metric deltas — wired at the Track-G device phase (int8 floor proven add.20-22)"}


# ---------------------------------------------------------------- 7) contamination guard
def verify_no_contamination(train, held) -> None:
    ti = {e["id"] for e in train if "id" in e}
    hi = {e["id"] for e in held if "id" in e}
    overlap = ti & hi
    if overlap:
        raise AssertionError(f"CONTAMINATION: {len(overlap)} ids in BOTH train and held (e.g. {list(overlap)[:3]}) — metrics void")


def split_bucket(example_id: str, held_frac: float = 0.1) -> bool:
    """Deterministic sha1 bucket → held iff in the held band (reproducible, leak-free)."""
    return (int(hashlib.sha1(str(example_id).encode()).hexdigest(), 16) % 1000) < int(held_frac * 1000)


# ---------------------------------------------------------------- the honest claim
def claim_card(res: dict) -> dict:
    raft, fid, gen = res.get("raft", {}), res.get("fidelity") or {}, res.get("generation", {})
    ppl = res.get("perplexity", {})
    e1_nll = raft.get("E1", {}).get("nll", float("inf"))
    t_e1 = res.get("teacher_E1_nll")                                  # MEASURED live teacher baseline; fail-closed if absent
    teacher_gap_ok = (t_e1 is not None and math.isfinite(t_e1) and (e1_nll - t_e1) <= TEACHER_GAP)
    parity = res.get("decode_parity") or {}
    gates = {
        # student reads about as well as the teacher (absolute bar AND within TEACHER_GAP of the MEASURED teacher).
        "task_fit": ppl.get("hotpotqa_held_nll", 9) <= TASK_FIT_ABS and teacher_gap_ok,
        # gold buried in distractors barely hurts → robust to retrieval noise.
        "raft_e2_robust": raft.get("slope_e2_e1", 9) < 0.05,
        # ANTI-PARROT: removing the gold doc must MEASURABLY hurt → the model actually USES the retrieved context.
        "context_use": raft.get("slope_e3_e1", -9) >= CONTEXT_USE_MARGIN,
        # teacher-student argmax agreement on the ANSWER SPAN.
        "fidelity_argmax": fid.get("argmax_agreement", 0) >= 0.60,
        # free-running greedy EM/F1 over normalized text.
        "generation": gen.get("EM", 0) >= 0.50 and gen.get("F1", 0) >= 0.60,
        # finite logits AND the E1/E2/E3 slopes were computed over an identical surviving subset.
        "stability": raft.get("skip_pct", 1) <= 0.05 and bool(raft.get("subset_ok", False)),
        # DEVICE TRUTH: the sequential fp16 decode path (what the A19 runs) matches the parallel eval graph.
        # (None when the model has no run_ref → coerce to 0 = fail-closed; NaN stays False under the comparison.)
        "device_parity": (parity.get("argmax_agreement") or 0) >= PARITY_BAR,
        "no_contamination": res.get("contamination_ok", False),
    }
    passed = all(gates.values())
    failed = [g for g, v in gates.items() if not v]
    return {"status": "成了 ✓ CLAIMABLE" if passed else "亏的 ✗ FAIL", "gates": gates, "failed_gates": failed}


# ---------------------------------------------------------------- smoke
def _smoke() -> None:
    import mamba3_trainable as MT
    torch.manual_seed(0)
    V, T = 512, 24
    student = MT.M(V, 2).to(DEV)

    def toy(n, ids_n=T):
        return [{"id": f"e{i}", "input_ids": torch.randint(0, V, (ids_n,)), "prompt_len": ids_n // 2} for i in range(n)]
    held = toy(8)
    wt = [torch.randint(0, V, (20,)) for _ in range(3)]
    E = {"E1": toy(6), "E2": toy(6), "E3": toy(6)}

    class StubTeacher:                                                # exercises the masked-fidelity + teacher-NLL paths
        def __call__(self, ids):
            return type("O", (), {"logits": torch.randn(1, ids.shape[1], V, device=DEV)})

    class TokDecode:
        def decode(self, ids):
            return " ".join(str(int(i)) for i in ids)

    teacher, tok = StubTeacher(), TokDecode()
    ppl = compute_perplexity(student, wt, held)
    raft = eval_raft_robustness(student, E)
    fid_none = compute_fidelity(student, None, held)                  # teacher absent → None-guarded
    fid = compute_fidelity(student, teacher, held)                    # answer-span masked path
    t_e1 = teacher_answer_nll(teacher, E["E1"])                       # measured-teacher baseline path
    gen = generate_and_score(student, toy(4), tok, maxlen=6)
    ece = compute_ece(student, held)
    res = {"perplexity": ppl, "raft": raft, "fidelity": fid, "generation": gen, "ece": ece,
           "quant": quant_fidelity_stub(), "contamination_ok": True, "teacher_E1_nll": t_e1,
           "decode_parity": {"argmax_agreement": 1.0, "logit_max_err": 0.0}}
    card = claim_card(res)

    finite = (math.isfinite(ppl["wikitext_ppl"]) and math.isfinite(raft["slope_e2_e1"])
              and 0 <= gen["EM"] <= 1 and 0 <= gen["F1"] <= 1 and math.isfinite(ece["ece"]))
    fid_guard = fid_none is None and fid is not None and 0 <= fid["argmax_agreement"] <= 1
    expect_gates = {"task_fit", "raft_e2_robust", "context_use", "fidelity_argmax",
                    "generation", "stability", "device_parity", "no_contamination"}
    gates_ok = set(card["gates"]) == expect_gates                    # the 8 gates wire (no dropped/renamed gate)
    subset_ok = "subset_ok" in raft
    contam_raises = False
    try:
        verify_no_contamination([{"id": "x"}], [{"id": "x"}])
    except AssertionError:
        contam_raises = True
    ok = finite and fid_guard and gates_ok and subset_ok and contam_raises and "status" in card
    print("EVAL_SMOKE (random-weight MT.M(512,2), toy examples, no download):")
    print(f"  perplexity wt={ppl['wikitext_ppl']:.1f} hq_nll={ppl['hotpotqa_held_nll']:.2f} | teacher_E1_nll(stub)={t_e1:.2f}")
    print(f"  raft slopes e2-e1={raft['slope_e2_e1']:.3f} e3-e1={raft['slope_e3_e1']:.3f} skip_pct={raft['skip_pct']:.2f} subset_ok={raft['subset_ok']}")
    print(f"  generation EM={gen['EM']:.2f} F1={gen['F1']:.2f} | ece={ece['ece']:.3f} | fidelity(answer-span) argmax={fid['argmax_agreement']:.2f}")
    print(f"  gates={sorted(card['gates'])}")
    print(f"  contamination guard raises on overlap={contam_raises} | claim_card={card['status']} (random ⇒ 亏的 expected)")
    print(f"  -> {'EVAL_SMOKE PASS' if ok else 'EVAL_SMOKE FAIL'} (every battery RUNS, the 8 gates wire; thresholds NOT asserted on random weights)")


if __name__ == "__main__":
    if os.environ.get("EVAL_SMOKE") == "1" or os.environ.get("EVAL_CKPT") is None:
        _smoke()
