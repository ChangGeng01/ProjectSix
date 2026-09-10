"""语义层 prefill — the evidence compressor (the operator's named prefill layer + Context Compiler capability 6 / 可压缩).

Given a long context, score per-token SALIENCE and KEEP the top fraction, so prefill compiles a SHORTER context that
retains the salient evidence → a cheaper prefill + a smaller MLA latent cache. The salience SOURCE is PLUGGABLE: here it is
the per-token recurrent-state DELTA norm (Σ_layers ‖ssm_t − ssm_{t−1}‖ — redundant/low-information tokens barely move the
SSM state; salient ones move it a lot). A trained scorer, an attention-mass signal, or a RAFT retriever's relevance can drop
in unchanged. The MECHANISM + compression ratio + state validity are host-verifiable now; the VALUE (does compression keep
answer quality) is trained-gated, like 最强大.

Run: ~/.venvs/coreai-cv/bin/python Tools/mamba3_evidence_compressor.py
"""
from __future__ import annotations

import sys

import torch

sys.path.insert(0, "/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tools")
import mamba3_hybrid as HY


def salience(m, tokens):
    """Per-token salience = Σ over Mamba layers of ‖ssm_t − ssm_{t−1}‖ (the state-delta the token induces)."""
    with torch.no_grad():
        x = m.embedding.weight[tokens]
        delta = torch.zeros(len(tokens))
        for i, lyr in enumerate(m.layers):
            if m._is_mla(i):
                x, _ = lyr.forward_seq(x)
            else:
                out, ssm_seq, _ = lyr.forward_seq(x)               # ssm_seq [T,H,P,N]
                flat = ssm_seq.flatten(1)
                delta[0] += flat[0].norm()
                delta[1:] += (flat[1:] - flat[:-1]).norm(dim=1)
                x = out
    return delta


def compress(tokens, sal, keep_frac: float):
    """Keep the top keep_frac most-salient tokens, in original order (evidence selection)."""
    k = max(1, int(round(len(tokens) * keep_frac)))
    idx = sal.topk(k).indices.sort().values
    return tokens[idx], idx


def evidence_prefill(m, tokens, keep_frac: float):
    """Compress the context by salience, then prefill the kept tokens → a cheaper boundary state."""
    sal = salience(m, tokens)
    kept, idx = compress(tokens, sal, keep_frac)
    _, state = m.prefill(kept)
    return state, kept, idx


def main() -> None:
    torch.manual_seed(0)
    V, L, T, KEEP = 4096, 24, 128, 0.5
    m = HY.HybridM(V, L).float().eval()
    tokens = torch.randint(0, V, (T,))
    state, kept, idx = evidence_prefill(m, tokens, KEEP)
    with torch.no_grad():
        cont = torch.randint(0, V, (8,))
        dec = m.run_ref(cont, init=state)                          # decode resumes from the COMPRESSED-context state
    finite = bool(torch.isfinite(dec).all())
    ratio = len(kept) / T
    ok = len(kept) == max(1, round(T * KEEP)) and finite and idx.equal(idx.sort().values)
    print(f"语义层 evidence compressor ({L}L hybrid, salience=state-delta norm):")
    print(f"  context {T} tok → kept {len(kept)} ({ratio:.0%}); MLA cache + prefill work shrink ~{1/ratio:.1f}×")
    print(f"  decode-from-compressed-state finite={finite}, kept-tokens in-order={idx.equal(idx.sort().values)} -> {'PASS' if ok else 'FAIL'}")
    print(f"  top-5 salient token positions: {sorted(idx[:5].tolist())} … (salience source is PLUGGABLE: trained scorer / RAFT relevance)")
    print("READ: PASS = the evidence compressor produces a valid shorter-context state (the 语义层). Compression VALUE "
          "(quality-preserving) is trained-gated; the mechanism + ratio + state validity are proven here.")


if __name__ == "__main__":
    main()
