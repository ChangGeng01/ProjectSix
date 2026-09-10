"""Stage-3 logit-KD smoke test: Granite-4.1-3b (dense, white-box teacher) -> Mamba-3 student, locally on MPS.

Proves the distillation LOOP works end-to-end: teacher loads, student (the PARITY-A-verified trainable twin)
consumes the SAME tokens, and KL(teacher||student) flows + DROPS over steps (student learns to mimic Granite on a
fixed batch), with argmax agreement rising. Stage-3 is logit-only, so the D mismatch (Granite 2560 vs student
1024) is irrelevant — KD aligns the [T,vocab] outputs, and student vocab == Granite vocab (100352) for free KD.

This is a smoke test on ONE fixed batch (overfit-style) — it validates gradients flow from the teacher signal,
NOT final quality. Run: ~/.venvs/coreai-cv/bin/python Tools/mamba3_distill.py
"""
from __future__ import annotations

import sys

import torch
import torch.nn.functional as F

sys.path.insert(0, "/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tools")
import mamba3_trainable as MT

TEACHER = "ibm-granite/granite-4.1-3b-base"
DEV = "mps" if torch.backends.mps.is_available() else "cpu"
TAU = 2.0
TEXT = ("The Apple Neural Engine accelerates on-device machine learning. State-space models such as Mamba "
        "decode efficiently with constant memory. Knowledge distillation transfers a teacher's behavior into "
        "a smaller student network that runs on the phone.")


def main() -> None:
    from transformers import AutoModelForCausalLM, AutoTokenizer

    tok = AutoTokenizer.from_pretrained(TEACHER)
    teacher = AutoModelForCausalLM.from_pretrained(TEACHER, torch_dtype=torch.float16).to(DEV).eval()
    vocab = teacher.config.vocab_size
    print(f"teacher {TEACHER} loaded: vocab={vocab}, hidden={teacher.config.hidden_size} | student D={MT.D_MODEL}")

    student = MT.M(vocab, layers=4).to(DEV)                       # locked student arch, Granite vocab; L=4 for a fast proof
    sp = sum(p.numel() for p in student.parameters()) / 1e6
    opt = torch.optim.AdamW(student.parameters(), lr=3e-4)

    ids = tok(TEXT, return_tensors="pt").input_ids[0][:64].to(DEV)
    T = ids.shape[0]
    with torch.no_grad():
        tlogits = teacher(ids.unsqueeze(0)).logits[0].float()    # [T, vocab] — fixed soft targets
    tsoft = F.log_softmax(tlogits / TAU, dim=-1)
    tgt_argmax = tlogits.argmax(-1)

    def agreement() -> float:
        with torch.no_grad():
            sl, _ = student.run_twin(ids, collect_ssm=False)
        return (sl.argmax(-1) == tgt_argmax).float().mean().item()

    print(f"student {sp:.0f}M (L=4), T={T} tokens.  step0 agreement vs teacher: {agreement():.1%}")
    kd0 = ce0 = None
    for step in range(40):
        opt.zero_grad(set_to_none=True)
        slogits, _ = student.run_twin(ids, collect_ssm=False)    # [T, vocab]
        kd = F.kl_div(F.log_softmax(slogits / TAU, dim=-1), tsoft, log_target=True, reduction="batchmean") * (TAU * TAU)
        ce = F.cross_entropy(slogits[:-1], ids[1:])              # the lambda*CE-to-gold term
        loss = kd + 0.1 * ce
        loss.backward()
        torch.nn.utils.clip_grad_norm_(student.parameters(), 1.0)
        opt.step()
        if kd0 is None:
            kd0, ce0 = float(kd), float(ce)
        if step % 10 == 9:
            print(f"  step {step+1:2d}: KD={float(kd):.3f}  CE={float(ce):.3f}  agree={agreement():.1%}")

    print("=== STAGE-3 KD SMOKE ===")
    print(f"  KD: {kd0:.3f} -> {float(kd):.3f}   CE: {ce0:.3f} -> {float(ce):.3f}")
    print(f"  teacher->student argmax agreement: stepN={agreement():.1%}")
    ok = float(kd) < kd0 * 0.7
    print(f"  RESULT: {'PASS ✅ (KD flows + drops -> distillation loop works)' if ok else 'FAIL ❌'}")


if __name__ == "__main__":
    main()
