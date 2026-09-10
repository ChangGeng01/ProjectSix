"""PARITY-B — the export/quant fidelity gate the audit flagged as never-run. Does the int8 deploy reproduce
the fp32 trained student's tokens? Decode the SAME prompt through (i) the fp32 trained 16-layer student and
(ii) the same student with per-output-channel symmetric int{N} weight fake-quant (the exact scheme QuantLinear
uses), and report argmax-agreement + logit max-abs-err, gated like PARITY-A. Pure torch (no coreai_torch).

Run: ~/.venvs/coreai-cv/bin/python Tools/mamba3_parity_b.py [bits=8]
"""
from __future__ import annotations

import sys

import torch

sys.path.insert(0, "/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tools")
import mamba3_trainable as MT

VOCAB = 100352
CKPT = "/tmp/draft_coreai/mamba3_poc_student.pt"
BITS = int(sys.argv[1]) if len(sys.argv) > 1 else 8
TEACHER = "ibm-granite/granite-4.1-3b-base"


def fq(w: torch.Tensor, bits: int) -> torch.Tensor:
    qmax = (1 << (bits - 1)) - 1
    s = (w.abs().amax(dim=1, keepdim=True) / qmax).clamp_min(1e-8)
    return torch.clamp(torch.round(w / s), -qmax - 1, qmax) * s


def build(quant: bool, L: int) -> MT.M:
    m = MT.M(VOCAB, L).eval()
    sd = torch.load(CKPT, map_location="cpu")["model"]
    missing, unexpected = m.load_state_dict(sd, strict=False)
    assert not [k for k in sd if k not in m.state_dict()], "checkpoint has tensors the model lacks"
    if quant:
        with torch.no_grad():
            for l in m.layers:
                for lin in (l.in_proj, l.out_proj, l.mlp_gate, l.mlp_up, l.mlp_down):
                    lin.weight.copy_(fq(lin.weight, BITS))
            m.embedding.weight.copy_(fq(m.embedding.weight, BITS))
    return m


def main() -> None:
    from transformers import AutoTokenizer
    L = torch.load(CKPT, map_location="cpu")["layers"]
    tok = AutoTokenizer.from_pretrained(TEACHER)
    prompts = [
        "The capital of France is Paris. State-space models decode efficiently on device.",
        "In a quiet seaside town, a lighthouse keeper discovered an old wooden box.",
        "def fibonacci(n):\n    if n <= 1:\n        return n\n    return fibonacci(n-1) + fibonacci(n-2)",
    ]
    m32, m8 = build(False, L), build(True, L)
    hits = tot = 0
    errs = []
    for p in prompts:
        ids = tok(p, return_tensors="pt").input_ids[0][:64]
        with torch.no_grad():
            l32 = m32.run_twin(ids, collect_ssm=False)[0]
            l8 = m8.run_twin(ids, collect_ssm=False)[0]
        hits += int((l32.argmax(-1) == l8.argmax(-1)).sum()); tot += ids.shape[0]
        errs.append((l32 - l8).abs().max().item())
    agree = hits / tot
    print(f"=== PARITY-B (int{BITS} fake-quant vs fp32, L={L} trained student, {tot} tokens) ===")
    print(f"  fp32-vs-int{BITS} argmax-agreement : {agree:.1%}  ({hits}/{tot})")
    print(f"  logit max-abs-err (worst prompt)  : {max(errs):.3f}")
    ok = agree >= 0.95
    print(f"  RESULT: {'PASS ✅ (int deploy reproduces the trained tokens)' if ok else 'WARN ⚠️ (int quant shifts tokens)'}")


if __name__ == "__main__":
    main()
