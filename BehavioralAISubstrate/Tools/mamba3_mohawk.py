"""Full white-box MOHAWK distillation: Granite-4.1-3b(dense) -> Mamba-3, SEQUENTIAL Stage-1 -> Stage-2 -> Stage-3,
with a REAL held-out metric (KL + perplexity, not just argmax). This is the audit-corrected version:

  Stage-1 (matrix orientation): align each student layer's materialized SSD token-mixing matrix (M.attn_matrix)
           to the teacher's softmax-attention matrix (GQA-grouped to the student's 16 heads), Frobenius.
  Stage-2 (hidden alignment): match student per-layer hiddens to the teacher's via a FROZEN orthogonal
           projection (NOT a free trained one — the audit showed a free projection launders the loss).
  Stage-3 (logit-KD): KL(teacher||student) + CE.

Run sequentially: STAGE=all (default) does 1 then 2 then 3, each STEPS steps. Or STAGE=1|2|3 for one stage.
Env: STEPS (100), T (192). Teacher loaded attn_implementation=eager (needed for attention weights).
"""
from __future__ import annotations

import os
import sys

import torch
import torch.nn.functional as F

sys.path.insert(0, "/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tools")
import mamba3_trainable as MT
from mamba3_poc_distill import load_chunks

TEACHER = "ibm-granite/granite-4.1-3b-base"
DEV = "mps" if torch.backends.mps.is_available() else "cpu"
TAU = 2.0
STEPS = int(os.environ.get("STEPS", "100"))
T = int(os.environ.get("T", "192"))
STAGE = os.environ.get("STAGE", "all")
LAYERS = 16


def group_heads(att, n):                                              # [gH,T,T] -> [n,T,T] by averaging groups
    gH = att.shape[0]
    if gH % n == 0:
        return att.view(n, gH // n, *att.shape[1:]).mean(1)
    idx = [round(i * gH / n) for i in range(n)]
    return att[idx]


def rel_fro(s, t):                                                   # canonical MOHAWK Stage-1 objective
    # ||S - T||_F / ||T||_F per head, averaged. Scale-correct (the student SSD matrix is a SIGNED operator
    # at init ~O(50); the teacher is row-stochastic ~O(1) — raw MSE would be dominated by the student's scale).
    num = torch.linalg.matrix_norm(s - t, ord="fro")
    den = torch.linalg.matrix_norm(t, ord="fro").clamp_min(1e-6)
    return (num / den).mean()


def main() -> None:
    from transformers import AutoModelForCausalLM, AutoTokenizer
    torch.manual_seed(0)
    tok = AutoTokenizer.from_pretrained(TEACHER)
    teacher = AutoModelForCausalLM.from_pretrained(TEACHER, dtype=torch.bfloat16,    # bf16: fp32 range, no fp16 overflow
                                                   attn_implementation="eager").to(DEV).eval()
    for p in teacher.parameters():
        p.requires_grad_(False)
    vocab, gL, gD = teacher.config.vocab_size, teacher.config.num_hidden_layers, teacher.config.hidden_size
    gmap = [round((i + 1) * gL / LAYERS) for i in range(LAYERS)]
    chunks = load_chunks(tok, STEPS + 16)
    held, train = chunks[:8], chunks[8:]          # FIXED held set (deterministic prefix) — STEPS-independent, so
    #                                               KL/ppl are comparable across runs of different length (audit fix)
    student = MT.M(vocab, LAYERS).to(DEV)

    # FROZEN orthogonal projection student(1024)->teacher(gD) for Stage-2 (audit fix: not trainable)
    proj = torch.empty(MT.D_MODEL, gD, device=DEV)
    torch.nn.init.orthogonal_(proj)
    proj = proj.detach()

    @torch.no_grad()
    def evaluate() -> tuple[float, float, float, int]:
        student.eval(); kl = ce = hits = ntok = nseq = 0.0; skipped = 0
        for ids in held:
            ids = ids.to(DEV)
            tl = teacher(ids.unsqueeze(0)).logits[0].float()
            sl = student.run_twin(ids, collect_ssm=False)[0]
            if not (torch.isfinite(tl).all() and torch.isfinite(sl).all()):   # robust: drop a bad chunk, count it
                skipped += 1; continue
            kl += float(F.kl_div(F.log_softmax(sl, -1), F.log_softmax(tl, -1), log_target=True, reduction="batchmean"))
            ce += float(F.cross_entropy(sl[:-1], ids[1:])) * (ids.shape[0] - 1)
            hits += float((sl.argmax(-1) == tl.argmax(-1)).sum()); ntok += ids.shape[0] - 1; nseq += 1
        student.train()
        if nseq == 0:
            return float("nan"), float("nan"), 0.0, skipped
        return kl / nseq, float(torch.tensor(ce / ntok).exp()), hits / ntok, skipped

    def run_stage(stage: str, opt) -> None:
        print(f"--- Stage-{stage} ({STEPS} steps) ---")
        for step in range(1, STEPS + 1):
            for g in opt.param_groups:
                g["lr"] = g["base"] * min(1.0, step / 30)
            ids = train[(step - 1) % len(train)][:T].to(DEV)
            opt.zero_grad(set_to_none=True)
            if stage == "1":
                with torch.no_grad():
                    ta = teacher(ids.unsqueeze(0), output_attentions=True).attentions   # tuple gL x [1,gH,T,T]
                sm = student.run_attn(ids)                                               # list LAYERS x [16,T,T]
                loss = sum(rel_fro(sm[l], group_heads(ta[gmap[l] - 1][0].float(), 16)) for l in range(LAYERS)) / LAYERS
            elif stage == "2":
                with torch.no_grad():
                    th = [h[0].float() for h in teacher(ids.unsqueeze(0), output_hidden_states=True).hidden_states]
                _, sh = student.run_twin(ids, collect_ssm=False, return_hiddens=True)
                loss = sum(F.mse_loss(MT.rms(sh[l] @ proj, torch.ones(gD, device=DEV)),
                                      MT.rms(th[gmap[l]], torch.ones(gD, device=DEV))) for l in range(LAYERS)) / LAYERS
            else:  # stage 3
                with torch.no_grad():
                    tl = teacher(ids.unsqueeze(0)).logits[0].float()
                sl, _ = student.run_twin(ids, collect_ssm=False)
                kd = F.kl_div(F.log_softmax(sl / TAU, -1), F.log_softmax(tl / TAU, -1), log_target=True,
                              reduction="batchmean") * (TAU * TAU)
                loss = kd + 0.1 * F.cross_entropy(sl[:-1], ids[1:])
            assert torch.isfinite(loss), f"Stage-{stage} step {step}: non-finite loss {float(loss)} — training bug, not a metric artifact"
            loss.backward()
            torch.nn.utils.clip_grad_norm_(student.parameters(), 1.0)
            opt.step()
            if step % 50 == 0:
                kl, ppl, ag, sk = evaluate()
                print(f"  S{stage} step {step:3d} | loss={float(loss):.4f} | held-out KL={kl:.3f} ppl={ppl:.1f} agree={ag:.1%} skip={sk}")

    def opt_for(lr):
        o = torch.optim.AdamW(student.parameters(), lr=lr, weight_decay=0.1)
        for g in o.param_groups:
            g["base"] = lr
        return o

    kl, ppl, ag, sk = evaluate()
    print(f"INIT | held-out KL={kl:.3f} ppl={ppl:.1f} agree={ag:.1%} skip={sk} | teacher L{gL}/H{teacher.config.num_attention_heads}")
    stages = ["1", "2", "3"] if STAGE == "all" else [STAGE]
    for s in stages:
        run_stage(s, opt_for(2e-4))
    kl, ppl, ag, sk = evaluate()
    print(f"=== MOHAWK ({'->'.join(stages)}) DONE | held-out KL={kl:.3f} ppl={ppl:.1f} agree={ag:.1%} skip={sk} ===")


if __name__ == "__main__":
    main()
