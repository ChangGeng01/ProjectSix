"""White-box MOHAWK distillation Granite-4.1-3b(dense) -> Mamba-3, sequential Stage-1 -> Stage-2 -> Stage-3.

AUDIT-CORRECTED v2 (fixes the 18-finding adversarial audit of the v1 verdict):
  - Stage-1 group_heads now AVERAGES teacher heads into 16 contiguous bins (v1 SUBSAMPLED 16 of 40, dropping 24).
  - Stage-2 aligns the student hidden to a FROZEN TOP-SVD projection of the teacher hidden (the teacher's most-informative
    1024-dim subspace), NOT a random orthogonal subspace (v1's random proj left ~60% of teacher energy unreachable and made
    the target seed-arbitrary — which CONFOUNDED the v1 "staging is scale-null" verdict).
  - Eval sequences are sliced to T (v1 evaluated at POC_T=256 while training at 128 — a mislabeled length mismatch).
  - argmax-agree compares next-token predictions consistently (v1 counted T positions over a T-1 denominator).
  - HONEST FAIRNESS FRAME: both arms get the SAME Stage-3 budget (STEPS); the staged arm ALSO runs Stage-1+2 (PRESTEPS each)
    BEFORE Stage-3. So the question is the right one: "does pre-alignment help a FIXED Stage-3 budget?" (v1's "equal total
    compute" frame let the staged Stage-3 run fewer steps + reset its optimizer/warmup — a confound).
  - MULTI-SEED with mean +/- std (v1 was n=1, single seed).

Run:  STEPS=240 PRESTEPS=120 SEEDS=3 T=192 python Tools/mamba3_mohawk.py
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
STEPS = int(os.environ.get("STEPS", "240"))          # Stage-3 budget — IDENTICAL across both arms
PRESTEPS = int(os.environ.get("PRESTEPS", "120"))    # Stage-1 and Stage-2 steps for the STAGED arm (baseline uses 0)
SEEDS = int(os.environ.get("SEEDS", "3"))
T = int(os.environ.get("T", "192"))
N_BASIS = int(os.environ.get("N_BASIS", "16"))       # train chunks used to estimate the teacher SVD subspace
LAYERS = 16


def group_heads(att, n):                                              # [gH,T,T] -> [n,T,T]
    """AVERAGE the gH teacher heads into n contiguous bins (every head contributes — v1 subsampled and dropped 60%)."""
    gH = att.shape[0]
    if gH % n == 0:
        return att.view(n, gH // n, *att.shape[1:]).mean(1)
    return torch.stack([att[(j * gH) // n: ((j + 1) * gH) // n].mean(0) for j in range(n)], 0)


def rel_fro(s, t):                                                   # canonical MOHAWK Stage-1 objective
    num = torch.linalg.matrix_norm(s - t, ord="fro")
    den = torch.linalg.matrix_norm(t, ord="fro").clamp_min(1e-6)
    return (num / den).mean()


def build_svd_proj(teacher, basis_chunks, layers_needed: list) -> dict:
    """Frozen top-1024 right-singular vectors of each needed teacher layer's hidden (the most-informative subspace).
    Returns {teacher_layer_index: proj[gD, 1024]} so teacher_hidden @ proj is the meaningful 1024-dim target."""
    acc = {l: [] for l in layers_needed}
    with torch.no_grad():
        for ids in basis_chunks:
            hs = teacher(ids[:T].to(DEV).unsqueeze(0), output_hidden_states=True).hidden_states
            for l in layers_needed:
                acc[l].append(hs[l][0].float().cpu())
    proj = {}
    for l in layers_needed:
        H = torch.cat(acc[l], 0)                                     # [Ntok, gD] on CPU (MPS SVD is size-limited)
        assert H.shape[0] >= MT.D_MODEL, f"SVD basis {H.shape[0]} tokens < D_MODEL {MT.D_MODEL}: raise N_BASIS or T"
        _, _, Vh = torch.linalg.svd(H, full_matrices=False)         # Vh: [k, gD], rows = right singular vectors
        proj[l] = Vh[:MT.D_MODEL].t().contiguous().to(DEV)          # [gD, 1024], full rank
    return proj


def main() -> None:
    from transformers import AutoModelForCausalLM, AutoTokenizer
    tok = AutoTokenizer.from_pretrained(TEACHER)
    teacher = AutoModelForCausalLM.from_pretrained(TEACHER, dtype=torch.bfloat16,
                                                   attn_implementation="eager").to(DEV).eval()
    for p in teacher.parameters():
        p.requires_grad_(False)
    vocab, gL, gD = teacher.config.vocab_size, teacher.config.num_hidden_layers, teacher.config.hidden_size
    gmap = [round((i + 1) * gL / LAYERS) for i in range(LAYERS)]
    chunks = load_chunks(tok, STEPS + 16)
    held, train = chunks[:8], chunks[8:]                            # FIXED held set (deterministic), STEPS-independent
    layers_needed = sorted(set(gmap))
    PROJ = build_svd_proj(teacher, train[:N_BASIS], layers_needed)  # frozen meaningful Stage-2 targets
    print(f"MOHAWK v2 | teacher L{gL}/H{teacher.config.num_attention_heads}/D{gD} -> student L{LAYERS}/D{MT.D_MODEL} | "
          f"T={T} STEPS(S3)={STEPS} PRESTEPS(S1,S2)={PRESTEPS} SEEDS={SEEDS} | SVD basis={len(train[:N_BASIS])} chunks")

    @torch.no_grad()
    def evaluate(student) -> tuple[float, float, float, int]:
        student.eval(); kl = ce = hits = ntok = nseq = 0.0; skip = 0
        for ids in held:
            ids = ids[:T].to(DEV)
            tl = teacher(ids.unsqueeze(0)).logits[0].float()
            sl = student.run_twin(ids, collect_ssm=False)[0]
            if not (torch.isfinite(tl).all() and torch.isfinite(sl).all()):
                skip += 1; continue
            kl += float(F.kl_div(F.log_softmax(sl, -1), F.log_softmax(tl, -1), log_target=True, reduction="batchmean"))
            ce += float(F.cross_entropy(sl[:-1], ids[1:])) * (ids.shape[0] - 1)
            hits += float((sl[:-1].argmax(-1) == tl[:-1].argmax(-1)).sum())   # next-token agreement, consistent denom
            ntok += ids.shape[0] - 1; nseq += 1
        student.train()
        if nseq == 0:
            return float("nan"), float("nan"), 0.0, skip
        return kl / nseq, float(torch.tensor(ce / ntok).exp()), hits / ntok, skip

    def stage_loss(stage: str, student, ids):
        if stage == "1":
            with torch.no_grad():
                ta = teacher(ids.unsqueeze(0), output_attentions=True).attentions
            sm = student.run_attn(ids)
            return sum(rel_fro(sm[l], group_heads(ta[gmap[l] - 1][0].float(), 16)) for l in range(LAYERS)) / LAYERS
        if stage == "2":
            with torch.no_grad():
                th = [h[0].float() for h in teacher(ids.unsqueeze(0), output_hidden_states=True).hidden_states]
            _, sh = student.run_twin(ids, collect_ssm=False, return_hiddens=True)
            o = torch.ones(MT.D_MODEL, device=DEV)
            return sum(F.mse_loss(MT.rms(sh[l], o), MT.rms(th[gmap[l]] @ PROJ[gmap[l]], o)) for l in range(LAYERS)) / LAYERS
        with torch.no_grad():
            tl = teacher(ids.unsqueeze(0)).logits[0].float()
        sl, _ = student.run_twin(ids, collect_ssm=False)
        kd = F.kl_div(F.log_softmax(sl / TAU, -1), F.log_softmax(tl / TAU, -1), log_target=True,
                      reduction="batchmean") * (TAU * TAU)
        return kd + 0.1 * F.cross_entropy(sl[:-1], ids[1:])

    def train_stage(student, stage: str, steps: int):
        if steps <= 0:
            return
        opt = torch.optim.AdamW(student.parameters(), lr=2e-4, weight_decay=0.1)
        warm = max(1, min(30, steps // 4))
        for step in range(1, steps + 1):
            for g in opt.param_groups:
                g["lr"] = 2e-4 * min(1.0, step / warm)
            ids = train[(step - 1) % len(train)][:T].to(DEV)
            opt.zero_grad(set_to_none=True)
            loss = stage_loss(stage, student, ids)
            assert torch.isfinite(loss), f"Stage-{stage} step {step}: non-finite loss {float(loss)}"
            loss.backward()
            torch.nn.utils.clip_grad_norm_(student.parameters(), 1.0)
            opt.step()

    grid = {}
    for seed in range(SEEDS):
        for arm, pre in (("baseline", 0), ("staged", PRESTEPS)):
            torch.manual_seed(seed)
            student = MT.M(vocab, LAYERS).to(DEV)
            if pre > 0:
                train_stage(student, "1", pre)
                train_stage(student, "2", pre)
            train_stage(student, "3", STEPS)                        # SAME Stage-3 budget for both arms
            kl, ppl, ag, sk = evaluate(student)
            grid[(seed, arm)] = (kl, ppl, ag)
            print(f"  seed{seed} {arm:8s} (pre={pre}) | KL={kl:.3f} ppl={ppl:.1f} agree={ag:.1%} skip={sk}")

    def agg(arm):
        ks = torch.tensor([grid[(s, arm)][0] for s in range(SEEDS)])
        ps = torch.tensor([grid[(s, arm)][1] for s in range(SEEDS)])
        return ks.mean().item(), ks.std().item(), ps.mean().item()
    bk, bks, bp = agg("baseline"); sk_, sks, sp = agg("staged")
    diffs = torch.tensor([grid[(s, "staged")][0] - grid[(s, "baseline")][0] for s in range(SEEDS)])
    print("\n=== MOHAWK v2 — does pre-alignment help a FIXED Stage-3 budget? (KL: lower=better) ===")
    print(f"  baseline (Stage-3 only, {STEPS} steps)  : KL {bk:.3f} ± {bks:.3f} | ppl {bp:.1f}")
    print(f"  staged   (S1,S2 pre + same Stage-3)     : KL {sk_:.3f} ± {sks:.3f} | ppl {sp:.1f}")
    print(f"  paired ΔKL (staged - baseline) per seed : {[round(d, 3) for d in diffs.tolist()]} "
          f"| mean {diffs.mean().item():+.3f} ± {diffs.std().item():.3f}")
    helps = (diffs < 0).sum().item()
    print(f"  staged better (ΔKL<0) in {helps}/{SEEDS} seeds. "
          f"{'Pre-alignment HELPS' if diffs.mean().item() < -diffs.std().item() else 'NO clear effect (within seed noise)'}.")


if __name__ == "__main__":
    main()
