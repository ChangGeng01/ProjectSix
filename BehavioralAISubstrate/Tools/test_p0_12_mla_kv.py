"""P0-12 (battery): the MLA latent-KV cache is NON-CONTRACTIVE — unlike the Mamba state (errors decay, addendum 17),
every cached latent is re-read by softmax each decode step. Does int8/int4 quant of the cached PROMPT latents still hold?

(A) PARITY: MLABlock.forward_seq (prefill) == step-loop decode from an empty cache (the attention-path analog of PARITY-A).
(B) Quant floor + contractivity: prefill(prompt) -> quant the per-layer latent caches (fp16/int8/int4) -> decode the
    continuation -> argmax vs fp32. first64 vs last64 of the decode probes the non-contractive behavior: a quantized-prompt
    error does NOT decay via state contraction, but DILUTES as fresh full-precision decode latents accrue weight.

Run: ~/.venvs/coreai-cv/bin/python Tools/test_p0_12_mla_kv.py    Env: LAYERS(4) PROMPT(512) CONT(128) SEED(0)
"""
from __future__ import annotations

import os
import sys

import torch

sys.path.insert(0, "/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tools")
import mamba3_mla as MLA


def qd(t, bits):
    if bits >= 32:
        return t
    if bits == 16:
        return t.to(torch.float16).to(torch.float32)
    qmax = (1 << (bits - 1)) - 1
    scale = t.abs().max().clamp_min(1e-12) / qmax
    return torch.round(t / scale).clamp(-qmax, qmax) * scale


def main() -> None:
    torch.manual_seed(int(os.environ.get("SEED", "0")))
    L = int(os.environ.get("LAYERS", "4"))                  # the hybrid carries 4 MLA layers
    V, PROMPT, CONT = 4096, int(os.environ.get("PROMPT", "512")), int(os.environ.get("CONT", "128"))
    m = MLA.MLAStack(V, L).float().eval()
    seq = torch.randint(0, V, (PROMPT + CONT,))
    with torch.no_grad():
        lo_seq, _ = m.forward_seq(seq)
        lo_dec, _ = m.decode(seq, [None] * L)
        perr = (lo_seq - lo_dec).abs().max().item()
        pa = (lo_seq.argmax(-1) == lo_dec.argmax(-1)).float().mean().item()
        print(f"(A) MLA forward_seq vs step-decode PARITY ({L} layers, T={PROMPT + CONT}): logit max-err {perr:.2e}, argmax {pa:.0%}"
              f" -> {'PASS' if perr < 1e-3 and pa > 0.999 else 'FAIL'}")

        lo_p, caches = m.prefill(seq[:PROMPT])
        ref, _ = m.decode(seq[PROMPT:], caches)
        refarg = ref.argmax(-1)
        full_kv, latent = 2 * MLA.H_ATTN * MLA.D_HEAD, MLA.D_LATENT
        print(f"\n(B) latent-cache quant floor (prompt={PROMPT} cont={CONT}, {L} MLA layers; "
              f"KV/tok latent={latent} vs full-MHA={full_kv} = {full_kv // latent}x cut):")
        print(f"{'cache':>6} | {'logit max-err':>13} | {'argmax all':>10} | {'first64':>8} {'last64':>8}")
        for bits, nm in [(32, "fp32"), (16, "fp16"), (8, "int8"), (4, "int4")]:
            qc = [qd(c, bits) for c in caches]
            dec, _ = m.decode(seq[PROMPT:], qc)
            le = (dec - ref).abs().max().item()
            ag = (dec.argmax(-1) == refarg).float().mean().item()
            f64 = (dec[:64].argmax(-1) == refarg[:64]).float().mean().item()
            l64 = (dec[64:].argmax(-1) == refarg[64:]).float().mean().item()
            print(f"{nm:>6} | {le:13.2e} | {ag:9.0%} | {f64:7.0%} {l64:7.0%}")
    print("\nREAD: (A) parity = the decode KV path reproduces the prefill. (B) int8 latent cache should hold (softmax convexity "
          "bounds the error); first64 vs last64 shows the non-contractive error DILUTING as fresh decode latents accrue, NOT "
          "decaying via contraction. int8 holding = the MLA latent cache ships at the 16x KV cut.")


if __name__ == "__main__":
    main()
