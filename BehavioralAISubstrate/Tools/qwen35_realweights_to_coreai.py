#!/usr/bin/env python3
"""M2 de-risking increment: load a REAL Qwen3.5-4B GDN layer (4-bit MLX dequant) → faithful forward → CoreAI.

Proves the real-WEIGHT port path (not random weights): safetensors 4-bit dequant + the faithful GDN forward
(conv1d→silu→split→qk-rmsnorm→decay=exp(-exp(A_log)*softplus(a+dt_bias)), beta=sigmoid(b)→gated-delta recurrence
→gated-rmsnorm(out,z)→out_proj, from Qwen35.swift:228-296 + GatedDelta.swift:14-15) → lowers through coreai_torch.
Scope: ONE real GDN layer (layer 0), reduced embed/head (the layer's real weights are the point). Gated-norm form
is approximate (fidelity is M3, not M2). Decode single-token; conv window carried as state.
"""
from __future__ import annotations
import glob, json, shutil, struct, sys, time
from pathlib import Path
import numpy as np, torch, torch.nn as nn, torch.nn.functional as F
import coreai_torch

CKPT = glob.glob(str(Path.home() / ".cache/huggingface/hub/models--mlx-community--Qwen3.5-4B-4bit/snapshots/*/"))[0]
D, GV, GK, GHD, GROUP = 2560, 32, 16, 128, 64
KEYDIM = GK * GHD           # 2048 (q and k widths); v width = GV*GHD = 4096; qkv = 8192


def load_st():
    idx = json.load(open(Path(CKPT) / "model.safetensors.index.json")) if (Path(CKPT) / "model.safetensors.index.json").exists() else None
    files = sorted(glob.glob(str(Path(CKPT) / "*.safetensors")))
    store = {}
    for fp in files:
        with open(fp, "rb") as f:
            n = struct.unpack("<Q", f.read(8))[0]; hdr = json.loads(f.read(n)); base = 8 + n
            for k, m in hdr.items():
                if k == "__metadata__":
                    continue
                store[k] = (fp, base, m)
    return store


def raw(store, key):
    fp, base, m = store[key]
    dt = {"BF16": np.dtype(np.uint16), "F32": np.float32, "U32": np.uint32, "F16": np.float16}[m["dtype"]]
    s, e = m["data_offsets"]
    with open(fp, "rb") as f:
        f.seek(base + s); buf = f.read(e - s)
    a = np.frombuffer(buf, dtype=dt).reshape(m["shape"])
    if m["dtype"] == "BF16":
        a = (a.astype(np.uint32) << 16).view(np.float32)
    return torch.from_numpy(a.copy())


def dequant(store, key):
    """MLX 4-bit affine: weight U32 [out, in/8] packs 8 nibbles/word; scales/biases [out, in/group]. w=scale*q+bias."""
    w = raw(store, key + ".weight").to(torch.int64)          # [out, in/8] uint32 as int64
    sc = raw(store, key + ".scales").float(); bi = raw(store, key + ".biases").float()
    out, in8 = w.shape; inn = in8 * 8
    nib = torch.stack([(w >> (4 * b)) & 0xF for b in range(8)], -1).reshape(out, inn).float()   # [out, in]
    sc = sc.repeat_interleave(GROUP, 1)[:, :inn]; bi = bi.repeat_interleave(GROUP, 1)[:, :inn]
    return (sc * nib + bi).to(torch.float16)                 # [out, in] fp16


def lin(store, key):
    w = dequant(store, key); m = nn.Linear(w.shape[1], w.shape[0], bias=False); m.weight = nn.Parameter(w); return m


def rms(x, w=None, e=1e-6):
    y = x * torch.rsqrt(x.pow(2).mean(-1, keepdim=True) + e)
    return y * w if w is not None else y


class RealGDN(nn.Module):
    def __init__(s, st, i=0):
        super().__init__()
        p = f"language_model.model.layers.{i}."
        s.qkv = lin(st, p + "linear_attn.in_proj_qkv"); s.a = lin(st, p + "linear_attn.in_proj_a")
        s.b = lin(st, p + "linear_attn.in_proj_b"); s.z = lin(st, p + "linear_attn.in_proj_z")
        s.o = lin(st, p + "linear_attn.out_proj")
        s.A_log = nn.Parameter(raw(st, p + "linear_attn.A_log").float())
        s.dt_bias = nn.Parameter(raw(st, p + "linear_attn.dt_bias").float())
        s.convw = nn.Parameter(raw(st, p + "linear_attn.conv1d.weight").float().to(torch.float16))  # [8192,4,1]
        s.gn = nn.Parameter(raw(st, p + "linear_attn.norm.weight").to(torch.float16))                # [128]
        s.iln = nn.Parameter(raw(st, p + "input_layernorm.weight").to(torch.float16))
        s.gate = lin(st, p + "mlp.gate_proj"); s.up = lin(st, p + "mlp.up_proj"); s.down = lin(st, p + "mlp.down_proj")
        s.pln = nn.Parameter(raw(st, p + "post_attention_layernorm.weight").to(torch.float16))

    def forward(s, x, state, convwin):        # x [D]; state [GV,GHD,GHD]; convwin [3,8192]
        h = rms(x, s.iln)
        qkv = s.qkv(h)                         # [8192]
        win = torch.cat([convwin, qkv.view(1, 8192)], 0)          # [4,8192]
        conv = F.silu((win.t() * s.convw.view(8192, 4)).sum(-1))  # depthwise causal conv k=4 → [8192]
        q, k, v = conv[:KEYDIM].view(GK, GHD), conv[KEYDIM:2 * KEYDIM].view(GK, GHD), conv[2 * KEYDIM:].view(GV, GHD)
        q = rms(q).repeat_interleave(GV // GK, 0); k = rms(k).repeat_interleave(GV // GK, 0)   # qk-rmsnorm + GQA
        decay = torch.exp(-torch.exp(s.A_log) * F.softplus(s.a(h) + s.dt_bias)).view(GV, 1, 1)
        beta = torch.sigmoid(s.b(h)).view(GV, 1); z = s.z(h).view(GV, GHD)
        state = state * decay
        kv = (state * k.view(GV, 1, GHD)).sum(-1)
        state = state + k.view(GV, 1, GHD) * ((v - kv) * beta).view(GV, GHD, 1)
        y = (state * q.view(GV, 1, GHD)).sum(-1)              # [GV,GHD]
        y = (rms(y, s.gn) * F.silu(z)).reshape(GV * GHD)      # gated RMSNorm (approx; M3 verifies)
        h = x + s.o(y)
        h = h + s.down(F.silu(s.gate(rms(h, s.pln))) * s.up(rms(h, s.pln)))
        return h, state, win[1:]


class M(nn.Module):
    def __init__(s, st):
        super().__init__()
        s.gdn = RealGDN(st, 0)
        s.head = nn.Linear(D, 512, bias=False)               # reduced head (real layer is the point)
        s.register_buffer("state", torch.zeros(GV, GHD, GHD, dtype=torch.float16))
        s.register_buffer("convwin", torch.zeros(3, 8192, dtype=torch.float16))

    def forward(s, x):                                       # x [1,D] a hidden vector (skip embed for the probe)
        h, st, cw = s.gdn(x.view(D), s.state, s.convwin)
        s.state[:] = st; s.convwin[:] = cw
        return s.head(h).view(1, 512)


def main():
    print(f">> loading real 4-bit weights from {Path(CKPT).name}")
    st = load_st()
    m = M(st).eval().half()
    # sanity: dequant magnitudes sane?
    w = dequant(st, "language_model.model.layers.0.linear_attn.out_proj")
    print(f"    dequant out_proj: shape {tuple(w.shape)} mean|w|={w.abs().float().mean():.4f} (sane if ~1e-2..1e-1)")
    x = torch.zeros(1, D, dtype=torch.float16)
    out = m(x); print(f"    torch forward OK, logits {tuple(out.shape)}")
    t0 = time.time()
    ep = torch.export.export(m.eval(), (torch.zeros(1, D, dtype=torch.float16),))
    ep = ep.run_decompositions(coreai_torch.get_decomp_table())
    states = list(ep.graph_signature.buffers_to_mutate.values())
    print(f"    export+decomp OK; states: {states}")
    conv = coreai_torch.TorchConverter().add_exported_program(
        ep, input_names=["x"], output_names=["logits"], state_names=states, entrypoint_name="main")
    prog = conv.to_coreai(); prog.optimize()
    OUT = "/tmp/gdn_coreai/Qwen35RealWeights_L0.aimodel"
    if Path(OUT).exists():
        shutil.rmtree(OUT)
    Path(OUT).parent.mkdir(parents=True, exist_ok=True); prog.save_asset(Path(OUT))
    sz = (Path(OUT) / "main.mlirb").stat().st_size
    print(f">> ✅ REAL-WEIGHT GDN LAYER CONVERTED  {sz/1e6:.1f} MB  in {time.time()-t0:.0f}s")


if __name__ == "__main__":
    main()
