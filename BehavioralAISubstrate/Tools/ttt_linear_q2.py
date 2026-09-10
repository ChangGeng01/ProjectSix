#!/usr/bin/env python3
"""Q2 — does TTT-Linear's per-token fast-weight update LOWER through coreai_torch 0.4.0?

The cheap, checkpoint-free convertibility insurance probe from the TTT-vs-Mamba ladder.
NOT a quality test (random weights) — purely: does the toolchain lower the exotic ops a
TTT-Linear decode step needs, and does the resulting .aimodel compute the SAME thing as torch?

Exercises exactly the ops the research flagged as the open risk (verified from ttt-lm-pytorch/ttt.py):
  - in-proj → Q,K,V                                      (matmul, fine)
  - inner self-supervised loss target = XV - XK          (residual)
  - predict Z1 = XK @ W1 + b1                            (per-head batched matmul)
  - gradient via MANUAL LayerNorm-backward (ln_fused_l2_bwd) — mean/var/rsqrt + Jacobian
  - W1 fast-weight update via OUTER-PRODUCT einsum 'hi,hj->hij'  [nh, hd, hd]  <-- the suspect op
  - predict-with-updated-W: Z1_bar = XQ @ W1_new + b1
  - post-LN, SiLU gate, o_proj, residual
W1 is a mutated register_buffer (fused across layers, like Llamba's conv/ssm) -> CoreAI state.

Self-consistency IS the fidelity test: the torch module mutates W1 in place each step (state
accumulates); the .aimodel does the same in its CoreAI state. If host argmax == torch argmax over
N steps, the lowering is faithful. No external reference / no checkpoint needed.

Run from /tmp:  cd /tmp && /tmp/coreai-cv/bin/python /tmp/ttt_linear_q2.py
"""
from __future__ import annotations

import asyncio
import inspect
import shutil
from pathlib import Path

import numpy as np
import torch
import torch.nn as nn
import torch.nn.functional as F

OUT = "/tmp/draft_coreai/TTTLinear_probe_fp16.aimodel"
EPS = 1e-6

# small but structurally real dims (host convert tests OP LOWERING, not the device layer ceiling)
D_MODEL = 512
NH = 8
HD = 64          # nh*hd = 512 = d_model
L = 2
VOCAB = 1000
N_STEPS = 16


def ln(x: torch.Tensor, w: torch.Tensor, b: torch.Tensor) -> torch.Tensor:
    """LayerNorm via mean + mean-of-squares (NO aten.var.correction — the op coreai_torch 0.4.0
    can't lower; same trick the Mamba rmsnorm used)."""
    mu = x.mean(-1, keepdim=True)
    xc = x - mu
    var = (xc * xc).mean(-1, keepdim=True)
    return xc * torch.rsqrt(var + EPS) * w + b


def manual_ln_l2_grad(Z: torch.Tensor, target: torch.Tensor,
                      w: torch.Tensor, b: torch.Tensor) -> torch.Tensor:
    """grad of 0.5*||LayerNorm(Z)*w+b - target||^2  w.r.t. Z, computed by hand (NO autograd).
    Z,target: [nh, hd]; w,b: [hd]. This is the ln_fused_l2_bwd the TTT cell uses."""
    mu = Z.mean(-1, keepdim=True)
    var = ((Z - mu) ** 2).mean(-1, keepdim=True)   # mean-of-squares, not aten.var.correction
    rstd = torch.rsqrt(var + EPS)
    xhat = (Z - mu) * rstd                      # [nh, hd]
    y = xhat * w + b
    dy = y - target                             # dL/dy
    dxhat = dy * w                              # dL/dxhat
    hd = Z.shape[-1]
    # LayerNorm backward (standard):
    dZ = rstd * (dxhat - dxhat.mean(-1, keepdim=True)
                 - xhat * (dxhat * xhat).mean(-1, keepdim=True))
    return dZ                                    # [nh, hd]


class TTTLinearLayer(nn.Module):
    """ONE TTT-Linear decode step. W1 (the fast-weight hidden state) is read from the module-level
    fused buffer and the new W1 returned for a single write-back (mirrors Llamba's fused state)."""

    def __init__(self) -> None:
        super().__init__()
        self.ln1_w = nn.Parameter(torch.ones(D_MODEL))
        self.ln1_b = nn.Parameter(torch.zeros(D_MODEL))
        self.Wq = nn.Linear(D_MODEL, D_MODEL, bias=False)
        self.Wk = nn.Linear(D_MODEL, D_MODEL, bias=False)
        self.Wv = nn.Linear(D_MODEL, D_MODEL, bias=False)
        self.Weta = nn.Linear(D_MODEL, NH, bias=True)
        self.b1 = nn.Parameter(torch.zeros(NH, HD))
        self.lnw = nn.Parameter(torch.ones(HD))
        self.lnb = nn.Parameter(torch.zeros(HD))
        self.post_w = nn.Parameter(torch.ones(HD))
        self.post_b = nn.Parameter(torch.zeros(HD))
        self.Wg = nn.Linear(D_MODEL, D_MODEL, bias=False)
        self.Wo = nn.Linear(D_MODEL, D_MODEL, bias=False)

    def forward(self, x: torch.Tensor, W1: torch.Tensor) -> tuple:
        # x: [d_model]; W1: [nh, hd, hd]
        h = ln(x, self.ln1_w, self.ln1_b)
        XQ = self.Wq(h).view(NH, HD)
        XK = self.Wk(h).view(NH, HD)
        XV = self.Wv(h).view(NH, HD)
        target = XV - XK
        Z1 = torch.einsum("hi,hij->hj", XK, W1) + self.b1            # predict, current W
        grad = manual_ln_l2_grad(Z1, target, self.lnw, self.lnb)    # [nh, hd]  (LN-backward)
        eta = torch.sigmoid(self.Weta(h)).view(NH, 1, 1)            # learnable lr
        gW1 = torch.einsum("hi,hj->hij", XK, grad)                  # OUTER PRODUCT  [nh, hd, hd]
        W1_new = W1 - eta * gW1                                     # fast-weight update
        Z1_bar = torch.einsum("hi,hij->hj", XQ, W1_new) + self.b1   # predict, updated W
        Zbar = ln(Z1_bar, self.post_w, self.post_b)
        gate = F.silu(self.Wg(h))
        out = self.Wo(Zbar.reshape(D_MODEL) * gate)
        return x + out, W1_new


class TTTLinearDecode(nn.Module):
    def __init__(self) -> None:
        super().__init__()
        self.embedding = nn.Embedding(VOCAB, D_MODEL)
        self.layers = nn.ModuleList([TTTLinearLayer() for _ in range(L)])
        self.final_w = nn.Parameter(torch.ones(D_MODEL))
        self.final_b = nn.Parameter(torch.zeros(D_MODEL))
        self.register_buffer("W1_all", torch.zeros(L, NH, HD, HD))   # fused fast-weight state

    def forward(self, input_id: torch.Tensor) -> torch.Tensor:
        x = self.embedding(input_id).view(D_MODEL)
        W1_all = self.W1_all
        new_W1 = []
        for i, layer in enumerate(self.layers):
            x, nW = layer(x, W1_all[i])
            new_W1.append(nW)
        self.W1_all[:] = torch.stack(new_W1, 0)
        x = ln(x, self.final_w, self.final_b)
        return (x @ self.embedding.weight.t()).view(1, VOCAB)


async def _aw(x):
    return await x if inspect.isawaitable(x) else x


def torch_decode(model: TTTLinearDecode, n: int) -> list[int]:
    model.W1_all.zero_()
    ids, tok = [], 1
    with torch.no_grad():
        for _ in range(n):
            lg = model(torch.tensor([[tok]], dtype=torch.long)).view(-1)
            tok = int(lg.argmax())
            ids.append(tok)
    return ids


def host_decode(out_path: str, state_names: list[str], n: int, fp16: bool) -> list[int]:
    from coreai.runtime import AIModel, NDArray
    dt = np.float16 if fp16 else np.float32

    async def run():
        m = await _aw(AIModel.load(out_path))
        fn = await _aw(m.load_function("main"))
        st = {nm: NDArray(np.zeros((L, NH, HD, HD), dt)) for nm in state_names}
        ids, tok = [], 1
        for _ in range(n):
            res = await _aw(fn(inputs={"input_id": NDArray(np.array([[tok]], np.int32))}, state=st))
            tok = int(np.asarray(res["logits"].numpy()).reshape(-1).argmax())
            ids.append(tok)
        return ids
    return asyncio.run(run())


def main() -> None:
    import coreai_torch
    torch.manual_seed(0)
    print(f"=== Q2 — TTT-Linear convertibility probe (d={D_MODEL} nh={NH} hd={HD} L={L} vocab={VOCAB}) ===")

    model = TTTLinearDecode().eval()
    ref_ids = torch_decode(model, N_STEPS)
    print(f"   torch self-decode ids: {ref_ids}")

    print("\n>> converting fp16 → .aimodel (the toolchain question) …")
    model16 = TTTLinearDecode().eval()
    model16.load_state_dict(model.state_dict())
    model16 = model16.half()
    sample = (torch.zeros(1, 1, dtype=torch.long),)
    try:
        ep = torch.export.export(model16, sample)
        ep = ep.run_decompositions(coreai_torch.get_decomp_table())
        state_names = list(ep.graph_signature.buffers_to_mutate.values())
        print(f"   exported OK; states={state_names}")
        conv = coreai_torch.TorchConverter().add_exported_program(
            ep, input_names=["input_id"], output_names=["logits"],
            state_names=state_names, entrypoint_name="main")
        prog = conv.to_coreai()
        prog.optimize()
        if Path(OUT).exists():
            shutil.rmtree(OUT)
        Path(OUT).parent.mkdir(parents=True, exist_ok=True)
        prog.save_asset(Path(OUT))
        print(f"   ✅ CONVERTED + SAVED {OUT}")
    except Exception as e:  # noqa: BLE001
        import traceback
        print("   ❌ CONVERSION FAILED — TTT-Linear does NOT lower on coreai_torch 0.4.0:")
        traceback.print_exc()
        print(f"\n>> Q2 RESULT: TTT-Linear convertibility = ❌ FAIL ({type(e).__name__}: {e})")
        return

    # fidelity: host .aimodel must match the torch module (self-consistency)
    print("\n>> GATE — host .aimodel vs torch module (argmax self-consistency):")
    # rebuild a fp32 torch ref with the SAME weights for the comparison sequence
    host_ids = host_decode(OUT, state_names, N_STEPS, fp16=True)
    # compare host(fp16) to torch(fp32) — argmax should mostly agree if lowering is faithful
    match = sum(1 for a, b in zip(host_ids, ref_ids) if a == b)
    print(f"   torch ids: {ref_ids}")
    print(f"   host  ids: {host_ids}")
    print(f"   argmax match (fp16 host vs fp32 torch): {match}/{N_STEPS}")
    verdict = "✅ CONVERTS + faithful" if match >= N_STEPS - 2 else \
              ("⚠️ CONVERTS but fp16 drift" if match >= N_STEPS // 2 else "⚠️ CONVERTS but host≠torch (lowering bug)")
    print(f"\n>> Q2 RESULT: TTT-Linear convertibility = {verdict}  ({match}/{N_STEPS})")


if __name__ == "__main__":
    main()
