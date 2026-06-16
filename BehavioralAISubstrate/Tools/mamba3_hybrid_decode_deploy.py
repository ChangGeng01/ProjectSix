"""STEP 4 of the on-device DUET probe: the FULL 24L hybrid DECODE asset (resident-state per-token step) -> .aimodel.

The 20 Mamba layers reuse the device-proven angle-first 4-state decode (stacked buffers, like mamba3_deploy.DeployM). The 4
MLA layers are the hard part: their latent KV cache GROWS per token, but CoreAI state buffers are FIXED-shape. Reformulation:
each MLA layer holds a fixed `mla_kv[MAX_SEQ, D_LATENT]` buffer + a scalar `mla_fill` (# valid slots). Per step:
  - write c_t at slot=fill via a ONE-HOT mask (NOT dynamic indexing — the lowering-safe pattern): kv' = kv*(1-oh) + c_t*oh
  - attend q_t over the WHOLE buffer, MASK slots >= fill+1 to -inf (softmax → 0) so only the valid prefix contributes
  - fill' = fill + 1
This is mathematically IDENTICAL to the growing-cache `MLABlock.step` (slots beyond the prefix are masked out), which
`verify_host()` proves before any conversion. The decode asset's MLA state is initialized from the prefill's mla_all latents
(first prompt_len slots, fill=prompt_len) — the State-Cache handoff (STEP 5).

Run host-equivalence (no coreai needed): cd BehavioralAISubstrate && ~/.venvs/coreai-cv/bin/python Tools/mamba3_hybrid_decode_deploy.py
Convert:  CONVERT=1 uv run --with coreai-torch python Tools/mamba3_hybrid_decode_deploy.py
"""
from __future__ import annotations

import os
import sys

import torch
import torch.nn as nn
import torch.nn.functional as F

sys.path.insert(0, "/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tools")
import mamba3_hybrid as HY
import mamba3_mla as MLA
import mamba3_trainable as MT
from mamba3_trainable import H, N, P, R, rms

D = MT.D_MODEL
DC = MLA.D_LATENT
LAYERS = int(os.environ.get("LAYERS", "24"))
VOCAB = 4096
MAX_SEQ = int(os.environ.get("MAX_SEQ", "256"))


def mla_step_fixed(blk, x_t, kvcache, fill, max_seq):
    """Fixed-buffer MLA decode step. kvcache [max_seq,DC], fill [1] (valid slots before this step). Returns
    (out [D], kvcache' [max_seq,DC], fill' [1]). One-hot write + offset-mask == growing-cache MLABlock.step."""
    h = rms(x_t.unsqueeze(0), blk.attn_norm)                          # [1,D]
    q = blk.q_proj(h).view(1, blk.h, blk.dh)
    c_t = blk.kv_down(h)                                              # [1,DC]
    idx = torch.arange(max_seq, device=x_t.device)
    onehot = (idx == fill).to(kvcache.dtype).unsqueeze(-1)           # [max_seq,1] — slot to write
    kv = kvcache * (1 - onehot) + c_t * onehot                       # write c_t at slot=fill (no dynamic index)
    new_fill = fill + 1
    k = blk.k_up(kv).view(max_seq, blk.h, blk.dh)
    v = blk.v_up(kv).view(max_seq, blk.h, blk.dh)
    scores = torch.einsum("thd,shd->hts", q, k) * blk.scale          # [h,1,max_seq]
    mask = (idx >= new_fill).view(1, 1, max_seq)                     # slots >= fill+1 are invalid
    a = scores.masked_fill(mask, float("-inf")).softmax(-1)
    o = torch.einsum("hts,shd->thd", a, v).reshape(1, blk.h * blk.dh)
    x1 = x_t + blk.o_proj(o).squeeze(0)
    return x1 + blk._mlp(x1.unsqueeze(0)).squeeze(0), kv, new_fill


class HybridDecodeFixed(nn.Module):
    def __init__(self, vocab: int, layers: int, max_seq: int) -> None:
        super().__init__()
        self.m = HY.HybridM(vocab, layers)
        self.max_seq, self.vocab = max_seq, vocab
        n_mam = layers - len(self.m.mla_pos)
        n_mla = len(self.m.mla_pos)
        self.register_buffer("angle_all", torch.zeros(n_mam, H, N // 2))   # angle FIRST (segmenter discipline)
        self.register_buffer("ssm_all", torch.zeros(n_mam, H, P, N))
        self.register_buffer("kprev_all", torch.zeros(n_mam, H, R, N))
        self.register_buffer("vprev_all", torch.zeros(n_mam, H, P, R))
        self.register_buffer("mla_kv", torch.zeros(n_mla, max_seq, DC))
        self.register_buffer("mla_fill", torch.zeros(n_mla, 1))

    def forward(self, input_id):                                     # [1,1] long -> logits [1,VOCAB]
        ew = self.m.embedding.weight
        x = F.embedding(input_id, ew).view(D)                        # [D] — gather (NOT scalar .item(), which breaks export)
        mam, mla = 0, 0
        na, ns, nk, nv, nkv, nf = [], [], [], [], [], []
        for i, lyr in enumerate(self.m.layers):
            if self.m._is_mla(i):
                x, kvn, fn = mla_step_fixed(lyr, x, self.mla_kv[mla], self.mla_fill[mla], self.max_seq)
                nkv.append(kvn); nf.append(fn); mla += 1
            else:
                x, a, sm, k, v = lyr.step_ref(x, self.angle_all[mam], self.ssm_all[mam], self.kprev_all[mam], self.vprev_all[mam])
                na.append(a); ns.append(sm); nk.append(k); nv.append(v); mam += 1
        self.angle_all[:] = torch.stack(na); self.ssm_all[:] = torch.stack(ns)
        self.kprev_all[:] = torch.stack(nk); self.vprev_all[:] = torch.stack(nv)
        self.mla_kv[:] = torch.stack(nkv); self.mla_fill[:] = torch.stack(nf)
        return (rms(x, self.m.fw) @ ew.to(x.dtype).t()).view(1, self.vocab)

    def load_prefill(self, state, prompt_len):
        """Initialize resident state from a HybridM.prefill handoff (the State-Cache, STEP 5)."""
        na, ns, nk, nv, kv, fl = [], [], [], [], [], []
        for i, (tag, s) in enumerate(state):
            if tag == "mamba":
                a, sm, k, v = s; na.append(a); ns.append(sm); nk.append(k); nv.append(v)
            else:
                buf = torch.zeros(self.max_seq, DC); buf[:prompt_len] = s          # prompt latents in slots [0:prompt_len]
                kv.append(buf); fl.append(torch.tensor([float(prompt_len)]))
        self.angle_all[:] = torch.stack(na); self.ssm_all[:] = torch.stack(ns)
        self.kprev_all[:] = torch.stack(nk); self.vprev_all[:] = torch.stack(nv)
        self.mla_kv[:] = torch.stack(kv); self.mla_fill[:] = torch.stack(fl)


def verify_host() -> bool:
    torch.manual_seed(0)
    PROMPT, CONT = 64, 48
    dec = HybridDecodeFixed(VOCAB, LAYERS, MAX_SEQ).float().eval()
    ref_m = dec.m                                                    # SAME weights (shared module)
    seq = torch.randint(0, VOCAB, (PROMPT + CONT,))
    with torch.no_grad():
        mono = ref_m.run_ref(seq)[PROMPT:]                           # monolithic ground truth
        refarg = mono.argmax(-1)
        _, state = ref_m.prefill(seq[:PROMPT])
        dec.load_prefill(state, PROMPT)
        outs = torch.stack([dec(seq[PROMPT + t].view(1, 1))[0] for t in range(CONT)])
    le = (outs - mono).abs().max().item()
    ag = (outs.argmax(-1) == refarg).float().mean().item()
    print(f"STEP-4 host-equivalence (fixed-buffer hybrid decode vs monolithic run_ref; {LAYERS}L, MAX_SEQ={MAX_SEQ}, prompt={PROMPT} cont={CONT}):")
    print(f"  logit max-err {le:.2e}  argmax-agree {ag:.0%}  -> {'PASS' if le < 1e-3 and ag > 0.999 else 'FAIL'}")
    print("  READ: PASS = the one-hot-write + offset-mask MLA fixed-buffer decode is EXACT vs the growing-cache step → convert is safe.")
    return le < 1e-3 and ag > 0.999


def convert() -> None:
    import shutil
    from pathlib import Path
    import coreai_torch
    from coreai_torch._compression.utils import inject_subbyte_tensors
    torch.manual_seed(0)
    m = HybridDecodeFixed(VOCAB, LAYERS, MAX_SEQ).half().eval()
    ex = (torch.zeros(1, 1, dtype=torch.long),)
    _ = m(*ex)
    ep = torch.export.export(m, ex)
    ep = inject_subbyte_tensors(ep.run_decompositions(coreai_torch.get_decomp_table()))
    st = list(ep.graph_signature.buffers_to_mutate.values())
    print(f"STEP-4 convert: {len(st)} resident states -> {st[:6]}...")
    c = coreai_torch.TorchConverter().add_exported_program(
        ep, input_names=["input_id"], output_names=["logits"], state_names=st, entrypoint_name="main")
    p = c.to_coreai(); p.optimize()
    out = Path(f"/tmp/draft_coreai/Mamba3HybridDecode_L{LAYERS}_M{MAX_SEQ}.aimodel")
    if out.exists():
        shutil.rmtree(out)
    out.parent.mkdir(parents=True, exist_ok=True)
    p.save_asset(out)
    sz = sum(f.stat().st_size for f in out.rglob("*") if f.is_file()) / 1e6
    print(f"  CONVERTED -> {out} ({sz:.0f} MB)  states={len(st)}")


def ref_e2e() -> None:
    """Host E2E ground truth: deterministic tokens (mirrored in Swift) + the monolithic cont argmax the device must
    reproduce. HALF=1 runs fp16 on MPS for an apples-to-apples compare with the fp16 device (the fp32 ref can disagree at
    a near-tie token). Prints the top1-top2 logit MARGIN per position so any device flip can be checked as a near-tie."""
    PROMPT, CONT = int(os.environ.get("PROMPT", "64")), int(os.environ.get("CONT", "32"))
    half = os.environ.get("HALF") == "1"
    dev = "mps" if half and torch.backends.mps.is_available() else "cpu"
    torch.manual_seed(0)
    m = HY.HybridM(VOCAB, LAYERS).eval().to(dev)                 # SAME seed/VOCAB as the converters → same weights
    if half:
        m = m.half()
    toks = torch.tensor([(i * 17 + 5) % VOCAB for i in range(PROMPT + CONT)], dtype=torch.long, device=dev)
    with torch.no_grad():
        lg = m.run_ref(toks)[PROMPT:].float()
    arg = lg.argmax(-1).tolist()
    top2 = lg.topk(2, -1).values
    margin = (top2[:, 0] - top2[:, 1]).tolist()
    print(f"E2E-REF ({'fp16/MPS' if half else 'fp32/CPU'} PROMPT={PROMPT} CONT={CONT} VOCAB={VOCAB} tok[i]=(i*17+5)%{VOCAB}):")
    print(f"  HOSTREF_CONT_ARGMAX={','.join(map(str, arg))}")
    print(f"  margins (top1-top2)={[round(x, 3) for x in margin]}")
    print("  READ: the device DUET must match this; a device flip only at a TINY-margin position = fp16 near-tie, not a bug.")


def main() -> None:
    mode = os.environ.get("MODE", "")
    if os.environ.get("CONVERT") == "1":
        convert()
    elif mode == "ref":
        ref_e2e()
    else:
        verify_host()


if __name__ == "__main__":
    main()
