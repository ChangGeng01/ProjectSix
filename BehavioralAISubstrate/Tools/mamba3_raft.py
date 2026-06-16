"""Local RAFT-via-fine-tuning PoC for the Mamba-3 student (HotpotQA distractor setting, M5 Max / MPS).

Tests ONE falsifiable claim: does training the reader WITH distractors (+ sometimes no gold doc) make it robust
to retrieval noise, vs. training golden-only (oracle)? Two students, identical everything EXCEPT context
composition, evaluated on the SAME held-out questions under three retrieval conditions:
  E1 gold-only · E2 gold buried in K distractors · E3 K distractors, NO gold.

Honest headline = the degradation SLOPE  Δ = NLL(E2) - NLL(E1).  RAFT helps IFF  Δ_raft < Δ_oracle
(a condition×context interaction). A uniform RAFT win with no slope difference is generic regularization, NOT the
retrieval-noise mechanism. Per the design spec, at 300-500 steps a NULL (CI includes 0) is the EXPECTED outcome —
this harness MEASURES the effect, it is not built to manufacture one. 亏的不要.

Objective = masked next-token CE on the answer tokens only (faithful RAFT SFT — NO logit-KD by default: Granite is
not RAFT-trained, so distilling its soft targets would teach NON-robust behavior and confound the test).

Run:  ~/.venvs/coreai-cv/bin/python Tools/mamba3_raft.py            (full: smoke -> seeds × {oracle,raft} grid)
      RAFT_SMOKE=1 ... mamba3_raft.py                              (toy assertions only, no download/teacher)
Env: RAFT_P(0.8) RAFT_K(4) RAFT_T(1024) RAFT_COT(0) RAFT_STEPS(300) RAFT_SEEDS(1) RAFT_N(600) RAFT_LAYERS(16).
"""
from __future__ import annotations

import hashlib
import os
import random
import sys

import torch
import torch.nn.functional as F

sys.path.insert(0, "/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tools")
import mamba3_trainable as MT

TEACHER = "ibm-granite/granite-4.1-3b-base"
DEV = "mps" if torch.backends.mps.is_available() else "cpu"
P_GOLDEN = float(os.environ.get("RAFT_P", "0.8"))
K_DISTRACT = int(os.environ.get("RAFT_K", "4"))
MAX_LEN = int(os.environ.get("RAFT_T", "1024"))
COT = os.environ.get("RAFT_COT", "0") == "1"
STEPS = int(os.environ.get("RAFT_STEPS", "300"))
SEEDS = int(os.environ.get("RAFT_SEEDS", "1"))
N_ROWS = int(os.environ.get("RAFT_N", "600"))
LAYERS = int(os.environ.get("RAFT_LAYERS", "16"))
WARMUP, LR, DOC_CHARS = 40, 2e-4, 800


# ---------- data builder (HotpotQA distractor: native gold + distractor paragraphs) ----------
def build_example(row) -> dict:
    ctx, sf = row["context"], row["supporting_facts"]
    titles, sents = ctx["title"], ctx["sentences"]
    gold_titles = set(sf["title"])
    docs = [(t, " ".join(s)[:DOC_CHARS]) for t, s in zip(titles, sents)]
    golden = [d for d in docs if d[0] in gold_titles]
    distract = [d for d in docs if d[0] not in gold_titles]
    gold_sents = []
    for t, sid in zip(sf["title"], sf["sent_id"]):
        if t in titles:
            para = sents[titles.index(t)]
            if 0 <= sid < len(para):
                gold_sents.append(para[sid].strip())
    return {"id": row["id"], "question": row["question"], "answer": str(row["answer"]),
            "golden": golden, "distract": distract, "gold_sents": gold_sents}


def target_text(ex: dict, keep_gold: bool) -> str:
    if not COT:
        return " " + ex["answer"]
    if keep_gold and ex["gold_sents"]:
        return f" ##Reason: According to ##begin_quote## {ex['gold_sents'][0]} ##end_quote## ##Answer: {ex['answer']}"
    return f" ##Reason: Based on parametric knowledge. ##Answer: {ex['answer']}"


def _fmt_doc(idx: int, title: str, txt: str) -> str:
    return f"[Document {idx + 1} | {title}]\n{txt}\n"


def _select_docs(gold: list, distract: list, budget: int, tok, rng: random.Random) -> list:
    """Audit-fix (gold-survival): pick whole docs that fit `budget` tokens — ALL gold docs FIRST (guaranteed; never
    dropped in favor of a distractor), then distractors until the budget fills, then shuffle the kept set (kill the
    positional shortcut, gold still present). Fixes the front-truncation bug where a shuffled-to-the-back gold doc was
    silently cut out of E2/training (collapsing E2→E3 and corrupting the slope gate)."""
    def cost(t: str, txt: str) -> int:
        return len(tok(_fmt_doc(0, t, txt), add_special_tokens=False).input_ids)
    kept, used = [], 0
    for t, txt in gold:                                                 # gold guaranteed (kept even if it alone overflows)
        kept.append((t, txt)); used += cost(t, txt)
    fill_budget = max(0, budget - 32)                                   # margin absorbs per-doc header-index token drift
    for t, txt in distract:
        c = cost(t, txt)
        if used + c > fill_budget:
            continue                                                    # drop the distractor, NEVER the gold
        kept.append((t, txt)); used += c
    rng.shuffle(kept)                                                   # positional robustness; gold survives the shuffle
    return kept


def to_ids(gold: list, distract: list, question: str, answer: str, tok, rng: random.Random, ex_id=None) -> dict:
    # Tokenize the three pieces SEPARATELY so truncation drops only DOCUMENT tokens — the question + answer always survive
    # (the v1 bug: pids[:N] kept the doc front and dropped the trailing "Question: ... Answer:", removing the question).
    # GOLD docs are selected FIRST (gold-survival) so they are never the docs truncated away.
    bos = [tok.bos_token_id] if tok.bos_token_id is not None else []
    suffix_ids = tok(f"\nQuestion: {question}\nAnswer:", add_special_tokens=False).input_ids
    aids = tok(answer, add_special_tokens=False).input_ids
    budget = max(0, MAX_LEN - len(bos) - len(suffix_ids) - len(aids))   # reserve room for question + answer
    kept = _select_docs(gold, distract, budget, tok, rng)
    block = "".join(_fmt_doc(i, t, txt) for i, (t, txt) in enumerate(kept))
    doc_ids = tok(block, add_special_tokens=False).input_ids[:budget]   # backstop; gold prioritized so this rarely bites
    pids = bos + doc_ids + suffix_ids                                   # question (suffix) is NEVER trimmed
    full = pids + aids
    prompt_len = min(len(pids), len(full) - 1)                          # >=1 answer token predicted
    out = {"input_ids": torch.tensor(full), "prompt_len": prompt_len}
    if ex_id is not None:
        out["id"] = ex_id                                              # carry id → cross-condition (E1/E2/E3) subset alignment
    return out


def make_examples(rows_examples: list, keep_p: float, k: int, tok, seed: int) -> list:
    out = []
    for idx, ex in enumerate(rows_examples):
        rng = random.Random(seed * 100003 + idx)                       # per-(seed,idx) — reproducible across conditions
        keep = rng.random() < keep_p
        if keep:
            gold, distract = list(ex["golden"]), ex["distract"][:k]    # gold kept, never dropped
        else:
            gold, distract = [], ex["distract"][: k + len(ex["golden"])]   # doc-count held constant, no gold
        item = to_ids(gold, distract, ex["question"], target_text(ex, keep), tok, rng, ex.get("id"))
        if item["prompt_len"] >= 1 and item["input_ids"].numel() > item["prompt_len"]:
            out.append(item)
    return out


def make_eval_condition(rows_examples: list, mode: str, tok) -> list:
    """Frozen eval split — same for both trained students. mode in {E1 gold-only, E2 gold-buried, E3 no-gold}."""
    out = []
    for idx, ex in enumerate(rows_examples):
        rng = random.Random(7_000_003 + idx)
        if mode == "E1":
            gold, distract = list(ex["golden"]), []
        elif mode == "E2":
            gold, distract = list(ex["golden"]), ex["distract"][:K_DISTRACT]
        else:                                                          # E3: no gold, doc-count matched to E2
            gold, distract = [], ex["distract"][: K_DISTRACT + len(ex["golden"])]
        item = to_ids(gold, distract, ex["question"], target_text(ex, mode != "E3"), tok, rng, ex.get("id"))
        if item["prompt_len"] >= 1 and item["input_ids"].numel() > item["prompt_len"]:
            out.append(item)
    return out


# ---------- objective + eval ----------
def masked_ce(logits, ids, prompt_len: int):
    lp, tgt = logits[:-1], ids[1:]                                     # causal shift (project convention)
    mask = torch.arange(tgt.shape[0], device=ids.device) >= (prompt_len - 1)
    if not mask.any():
        return None
    return F.cross_entropy(lp[mask], tgt[mask], reduction="mean")


@torch.no_grad()
def eval_nll(student, examples: list) -> tuple[float, float, int]:
    student.eval()
    tot_nll = tot_tok = hits = 0.0
    skip = 0
    for ex in examples:
        ids = ex["input_ids"].to(DEV)
        logits, _ = student.run_twin(ids, collect_ssm=False)
        if not torch.isfinite(logits).all():
            skip += 1
            continue
        lp, tgt = logits[:-1], ids[1:]
        mask = torch.arange(tgt.shape[0], device=DEV) >= (ex["prompt_len"] - 1)
        if not mask.any():
            continue
        tot_nll += float(F.cross_entropy(lp[mask], tgt[mask], reduction="sum"))
        hits += float((lp[mask].argmax(-1) == tgt[mask]).sum())        # teacher-forced answer-token accuracy (cheap)
        tot_tok += int(mask.sum())
    student.train()
    return (tot_nll / tot_tok if tot_tok else float("nan"),
            hits / tot_tok if tot_tok else 0.0, skip)


def train_one(student, train_ex: list, steps: int, lr: float):
    opt = torch.optim.AdamW(student.parameters(), lr=lr, weight_decay=0.1)
    for step in range(1, steps + 1):
        for g in opt.param_groups:
            g["lr"] = lr * min(1.0, step / WARMUP)
        ex = train_ex[(step - 1) % len(train_ex)]
        ids = ex["input_ids"].to(DEV)
        opt.zero_grad(set_to_none=True)
        logits, _ = student.run_twin(ids, collect_ssm=False)
        loss = masked_ce(logits, ids, ex["prompt_len"])
        if loss is None:
            continue
        assert torch.isfinite(loss), f"step {step}: non-finite RAFT loss {float(loss)}"
        loss.backward()
        torch.nn.utils.clip_grad_norm_(student.parameters(), 1.0)
        opt.step()
    return student


# ---------- smoke (toy, no download/teacher) ----------
def smoke() -> None:
    print("RAFT_SMOKE: toy assertions (no dataset, no teacher)")

    class TokStub:
        bos_token_id = 1

        def __call__(self, s, add_special_tokens=True):
            ids = [ord(c) % 500 + 1 for c in s]
            return type("E", (), {"input_ids": ids})

    tok = TokStub()
    # [1] GOLD-SURVIVAL: under heavy budget pressure (many big distractors), gold docs must NOT be dropped — distractors are.
    gold = [("GOLD", "the one gold fact.")]
    distract = [(f"D{j}", "x" * 200) for j in range(20)]
    kept = _select_docs(gold, distract, budget=80, tok=tok, rng=random.Random(0))
    kept_titles = {t for t, _ in kept}
    assert "GOLD" in kept_titles, "GOLD-SURVIVAL FAILED: gold dropped under budget pressure (the audit bug)"
    assert len(kept) < 1 + len(distract), "excess distractors must be dropped when over budget (gold-aware truncation)"
    print(f"  [1] gold-survival OK (kept {len(kept)} docs incl. GOLD; dropped {1 + len(distract) - len(kept)} distractors)")

    # [2] to_ids carries id, never trims the question, predicts >=1 answer token
    it = to_ids(gold, distract[:4], "what is the answer?", " ans0", tok, random.Random(1), ex_id="qid")
    qtok = tok("\nQuestion: what is the answer?\nAnswer:", add_special_tokens=False).input_ids
    ntgt = it["input_ids"].numel() - 1
    m = torch.arange(ntgt) >= (it["prompt_len"] - 1)
    assert it.get("id") == "qid", "eval item must carry id for cross-condition alignment"
    assert it["prompt_len"] >= 1 and int(m.sum()) >= 1, "mask must cover >=1 answer token"
    assert it["input_ids"].numel() >= len(qtok), "question suffix must never be truncated away"
    print(f"  [2] to_ids/mask/id OK (len={it['input_ids'].numel()} prompt_len={it['prompt_len']} "
          f"answer_toks={int(m.sum())} id={it.get('id')})")

    torch.manual_seed(0)
    st = MT.M(512, 2).to(DEV)
    batch = []
    for i in range(4):
        full = torch.tensor([1] + [10 + i] * 6 + [20 + i, 21 + i])
        batch.append({"input_ids": full, "prompt_len": 7})
    opt = torch.optim.AdamW(st.parameters(), lr=3e-3)
    last = 9.9
    for s in range(60):
        ex = batch[s % 4]
        ids = ex["input_ids"].to(DEV)
        opt.zero_grad(set_to_none=True)
        lg, _ = st.run_twin(ids, collect_ssm=False)
        loss = masked_ce(lg, ids, ex["prompt_len"])
        loss.backward()
        torch.nn.utils.clip_grad_norm_(st.parameters(), 1.0)
        opt.step()
        last = float(loss)
    assert last < 0.10, f"overfit failed: masked answer-CE {last:.3f} (gradients not flowing through masked head)"
    print(f"  [3] overfit OK (masked answer-CE {last:.4f} < 0.10 over 60 steps)")

    # [4] DETERMINISM: make_eval_condition over the SAME rows twice → byte-identical (the frozen eval set is reproducible)
    toy_rows = [{"id": str(i), "question": f"q{i}?", "answer": f"a{i}",
                 "golden": [(f"G{i}", f"gold {i} fact.")],
                 "distract": [(f"D{i}_{j}", f"distractor {i} {j}.") for j in range(6)],
                 "gold_sents": [f"gold {i} fact."]} for i in range(5)]
    Ea = make_eval_condition(toy_rows, "E2", tok)
    Eb = make_eval_condition(toy_rows, "E2", tok)
    det = len(Ea) == len(Eb) and all(torch.equal(a["input_ids"], b["input_ids"]) and a.get("id") == b.get("id")
                                     for a, b in zip(Ea, Eb))
    assert det, "DETERMINISM FAILED: make_eval_condition not reproducible across builds (frozen eval set would drift)"
    print(f"  [4] eval-set determinism OK (E2 rebuilt byte-identical over {len(Ea)} examples)")
    print("RAFT_SMOKE PASS")


def main() -> None:
    if os.environ.get("RAFT_SMOKE") == "1":
        smoke()
        return
    from datasets import load_dataset
    from transformers import AutoTokenizer
    tok = AutoTokenizer.from_pretrained(TEACHER)
    vocab = tok.vocab_size
    rows = load_dataset("hotpotqa/hotpot_qa", "distractor", split=f"validation[:{N_ROWS}]",
                        revision=os.environ.get("HOTPOT_REVISION") or None)   # pin a commit SHA → fully reproducible source
    examples = [build_example(r) for r in rows]
    def bucket(idstr: str) -> int:                                          # stable hash (Python hash() is salted per process)
        return int(hashlib.sha1(idstr.encode()).hexdigest(), 16) % 10
    held = [e for e in examples if bucket(e["id"]) < 3]                     # ~30% held, split by question id, reproducible
    train_rows = [e for e in examples if bucket(e["id"]) >= 3]
    E = {m: make_eval_condition(held, m, tok) for m in ("E1", "E2", "E3")}
    print(f"RAFT | HotpotQA distractor | train_q={len(train_rows)} held_q={len(held)} "
          f"| P={P_GOLDEN} K={K_DISTRACT} T={MAX_LEN} CoT={COT} | eval E1/E2/E3={[len(E[m]) for m in E]} | vocab={vocab}")

    grid = {}
    for seed in range(SEEDS):
        for cond, (p, k) in (("oracle", (1.0, 0)), ("raft", (P_GOLDEN, K_DISTRACT))):
            torch.manual_seed(seed)
            student = MT.M(vocab, LAYERS).to(DEV)
            train_ex = make_examples(train_rows, p, k, tok, seed)
            train_one(student, train_ex, STEPS, LR)
            row = {}
            for m in ("E1", "E2", "E3"):
                nll, acc, sk = eval_nll(student, E[m])
                assert sk == 0, f"{m} dropped {sk} non-finite eval examples — slope would be over non-identical subsets"
                row[m] = (nll, acc)
            slope = row["E2"][0] - row["E1"][0]
            grid[(seed, cond)] = (row, slope)
            print(f"  seed{seed} {cond:6s} | E1 nll={row['E1'][0]:.3f} acc={row['E1'][1]:.1%} "
                  f"| E2 nll={row['E2'][0]:.3f} acc={row['E2'][1]:.1%} "
                  f"| E3 nll={row['E3'][0]:.3f} acc={row['E3'][1]:.1%} | slope Δ(E2-E1)={slope:+.3f}")

    print("\n=== RAFT vs ORACLE (paired, per seed) ===")
    for seed in range(SEEDS):
        ro, so = grid[(seed, "oracle")]
        rr, sr = grid[(seed, "raft")]
        print(f"  seed{seed}: Δ_oracle={so:+.3f}  Δ_raft={sr:+.3f}  | interaction (Δ_raft<Δ_oracle? = RAFT robust): "
              f"{'YES' if sr < so else 'no'}  | E2 nll raft-oracle={rr['E2'][0]-ro['E2'][0]:+.3f} "
              f"E3 nll raft-oracle={rr['E3'][0]-ro['E3'][0]:+.3f}")
    print("HEADLINE = the SLOPE interaction (Δ_raft < Δ_oracle), not any single-cell win. "
          "At this scale a null (no consistent interaction) is the pre-registered expected outcome.")


if __name__ == "__main__":
    main()
