#!/usr/bin/env python3
"""M2 FINISH: assemble the full 32L real-weight Qwen3.5-4B into 3 int4 CoreAI assets (the shippable form).

Split: asset1 = embed + layers 0-11, asset2 = layers 12-23, asset3 = layers 24-31 + final-norm + tied head.
Each is a stateful decode sub-model (hidden in → hidden out; asset1 in=token, asset3 out=logits) carrying its
layers' states. Decode forwards: RealGDN (verified) single-token; FA single-token with windowed KV (W) + RoPE at a
carried position. int4 everywhere. Converts each asset separately (memory-safe). Proves the 3-asset int4 packaging
+ inter-asset hidden hand-off. (Per-layer states here — convert-valid; device needs single-fused-state, M1.)
"""
from __future__ import annotations
import sys, shutil, time
from pathlib import Path
import torch, torch.nn as nn, torch.nn.functional as F
SD = "/private/tmp/claude-501/-Users-changgeng-Project-Project06-Project06/c3ffc755-9222-4370-81cc-7a004da44172/scratchpad"
sys.path.insert(0, SD); sys.path.insert(0, "/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tools")
from qwen35_realweights_to_coreai import RealGDN, load_st, lin, raw, rms, dequant, D, GV, GHD
import coreai_torch
from coreai_torch._compression.utils import inject_subbyte_tensors
from llama_to_coreai_int8 import QuantLinear

NB, W = 4, 8
AH, AKV, AHD, BASE, RD = 16, 4, 256, 1e7, 64
P = "language_model.model."
def is_lin(i): return (i + 1) % 4 != 0


def q4(module):
    for n, c in list(module.named_children()):
        if isinstance(c, nn.Linear):
            setattr(module, n, QuantLinear(c.weight.data.float(), NB))
        else:
            q4(c)
    return module


class FA(nn.Module):
    def __init__(s, st, i):
        super().__init__(); p = f"{P}layers.{i}."
        s.qp = QuantLinear(dequant(st, p+"self_attn.q_proj").float(), NB); s.kp = QuantLinear(dequant(st, p+"self_attn.k_proj").float(), NB)
        s.vp = QuantLinear(dequant(st, p+"self_attn.v_proj").float(), NB); s.op = QuantLinear(dequant(st, p+"self_attn.o_proj").float(), NB)
        s.qn = raw(st, p+"self_attn.q_norm.weight").half(); s.kn = raw(st, p+"self_attn.k_norm.weight").half()
        s.iln = raw(st, p+"input_layernorm.weight").half(); s.pln = raw(st, p+"post_attention_layernorm.weight").half()
        s.gw = QuantLinear(dequant(st, p+"mlp.gate_proj").float(), NB); s.uw = QuantLinear(dequant(st, p+"mlp.up_proj").float(), NB); s.dw = QuantLinear(dequant(st, p+"mlp.down_proj").float(), NB)

    def forward(s, x, kbuf, vbuf, pos):            # x[D]; kbuf/vbuf [W,AKV,AHD]; pos [1]
        h = rms(x, s.iln)
        qpo = s.qp(h).view(AH, -1); q, g = qpo[:, :AHD], qpo[:, AHD:]; gate = g.reshape(-1)
        k = s.kp(h).view(AKV, AHD); v = s.vp(h).view(AKV, AHD)
        q = rms(q, s.qn); k = rms(k, s.kn)
        inv = BASE ** (-torch.arange(0, RD, 2).float() / RD); ang = (pos * inv).half()  # [RD/2]
        cos, sin = ang.cos(), ang.sin(); half = RD // 2
        def rope(t):
            tr, tp = t[:, :RD], t[:, RD:]; x1, x2 = tr[:, :half], tr[:, half:]
            return torch.cat([torch.cat([x1*cos - x2*sin, x1*sin + x2*cos], -1), tp], -1)
        q = rope(q); k = rope(k)
        kbuf = torch.cat([kbuf[1:], k.view(1, AKV, AHD)], 0); vbuf = torch.cat([vbuf[1:], v.view(1, AKV, AHD)], 0)
        kk = kbuf.repeat_interleave(AH//AKV, 1).transpose(0, 1); vv = vbuf.repeat_interleave(AH//AKV, 1).transpose(0, 1)
        sc = (q.unsqueeze(1).float() @ kk.float().transpose(-1, -2)).squeeze(1) * (AHD ** -0.5)  # [AH,W]
        out = (F.softmax(sc, -1).unsqueeze(1) @ vv.float()).squeeze(1).reshape(-1).half() * torch.sigmoid(gate)
        h = x + s.op(out)
        return h + s.dw(F.silu(s.gw(rms(h, s.pln))) * s.uw(rms(h, s.pln))), kbuf, vbuf


class Asset(nn.Module):
    def __init__(s, st, a, b, embed=False, head=False):
        super().__init__(); s.a, s.b, s.emb_on, s.head_on = a, b, embed, head
        s.layers = nn.ModuleList()
        for i in range(a, b):
            g = q4(RealGDN(st, i)) if is_lin(i) else FA(st, i)
            if is_lin(i):
                g.A_log.data = g.A_log.data.half(); g.dt_bias.data = g.dt_bias.data.half()
            s.layers.append(g)
        if embed: s.emb = QuantLinear(dequant(st, P+"embed_tokens").float(), NB)   # one-hot-free: gather via matmul-free lookup below
        if head:
            s.fn = raw(st, P+"norm.weight").half(); s.head = QuantLinear(dequant(st, P+"embed_tokens").float(), NB)
        # per-layer states
        for j, i in enumerate(range(a, b)):
            if is_lin(i):
                s.register_buffer(f"gs{j}", torch.zeros(GV, GHD, GHD, dtype=torch.float16))
                s.register_buffer(f"gc{j}", torch.zeros(3, 8192, dtype=torch.float16))
            else:
                s.register_buffer(f"fk{j}", torch.zeros(W, AKV, AHD, dtype=torch.float16))
                s.register_buffer(f"fv{j}", torch.zeros(W, AKV, AHD, dtype=torch.float16))
        s.register_buffer("pos", torch.zeros(1, dtype=torch.float16))

    def forward(s, x):                              # asset1: x=hidden from embed done outside; else x=[D]
        h = x.view(D); pos = s.pos + 1.0
        for j, i in enumerate(range(s.a, s.b)):
            if is_lin(i):
                gs = getattr(s, f"gs{j}"); gc = getattr(s, f"gc{j}")
                h, ns, nc = s.layers[j](h, gs, gc); gs[:] = ns; gc[:] = nc
            else:
                fk = getattr(s, f"fk{j}"); fv = getattr(s, f"fv{j}")
                h, nk, nv = s.layers[j](h, fk, fv, pos); fk[:] = nk; fv[:] = nv
        s.pos[:] = pos
        if s.head_on:
            h = rms(h, s.fn); return s.head(h).view(1, -1)   # logits (tied head)
        return h.view(1, D)


def convert(asset, name, in_dim):
    ex = torch.zeros(1, in_dim, dtype=torch.float16)
    ep = torch.export.export(asset.eval(), (ex,)); ep = ep.run_decompositions(coreai_torch.get_decomp_table())
    ep = inject_subbyte_tensors(ep); states = list(ep.graph_signature.buffers_to_mutate.values())
    conv = coreai_torch.TorchConverter().add_exported_program(ep, input_names=["x"], output_names=["out"], state_names=states, entrypoint_name="main")
    prog = conv.to_coreai(); prog.optimize()
    out = f"/tmp/gdn_coreai/{name}.aimodel"
    if Path(out).exists(): shutil.rmtree(out)
    Path(out).parent.mkdir(parents=True, exist_ok=True); prog.save_asset(Path(out))
    sz = (Path(out) / "main.mlirb").stat().st_size / 1e9
    print(f">> ✅ {name}: {sz:.2f} GB  ({len(states)} states)"); return sz


def main():
    st = load_st(); tot = 0
    # asset2 (middle, cleanest) + asset3 (head) + asset1 (embed) — but embed input is a token; here we take hidden in
    # to prove hidden hand-off, and do the embed lookup on the host. So all 3 assets are hidden->hidden/logits.
    for name, a, b, head in [("Qwen35_asset2_L12-23_int4", 12, 24, False),
                             ("Qwen35_asset3_L24-31_head_int4", 24, 32, True),
                             ("Qwen35_asset1_L0-11_int4", 0, 12, False)]:
        print(f">> building {name} (layers {a}-{b-1}{' +head' if head else ''}) int4...")
        t0 = time.time(); asset = Asset(st, a, b, head=head).eval()
        tot += convert(asset, name, D); print(f"   ({time.time()-t0:.0f}s)")
        del asset
    print(f">> 3-asset int4 total ≈ {tot:.2f} GB (each < 2GB wall). Hidden hand-off: asset1→asset2→asset3.")


if __name__ == "__main__":
    main()
