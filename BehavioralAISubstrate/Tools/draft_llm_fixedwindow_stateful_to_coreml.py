#!/usr/bin/env python3
"""B1' — ANE-FRIENDLY fixed-window stateful KV-cache decoder (salvage the declined B2 hybrid).

B1 found that a NAIVE stateful decoder (`draft_llm_stateful_to_coreml.py`) plans 100% onto the GPU, not the
ANE — the two dynamic ops that pushed the whole graph off the ANE were:
  (1) the position-indexed scatter write  `k_cache[li, :, :, pos, :] = k`   (advanced indexing, runtime `pos`)
  (2) the runtime causal mask            `mask = (arange(MAX_SEQ) <= pos)`  (runtime compare + masked_fill)

This rewrite removes BOTH by replacing them with ELEMENTWISE ops gated by HOST-precomputed inputs (the
fixed-window pattern Apple's own on-device Core ML LLMs use — no dynamic indexing inside the graph):
  (1) write via a one-hot SELECT:   kc_new = kc * (1 - write_onehot) + k * write_onehot   (pure mul/add)
  (2) mask via an ADDITIVE bias:    scores = scores + attn_bias                            (pure add)
where `write_onehot` ([MAX_SEQ], 1 at the current position) and `attn_bias` ([MAX_SEQ], 0 for valid / large
negative for future) are computed cheaply on the host each step and passed as fp16 inputs. The layer index is a
compile-time Python constant (loop-unrolled), so per-layer state is held in SEPARATE buffers — zero dynamic
index anywhere in the traced graph.

Question this answers (measured, not argued): does the fixed-window formulation keep the matmuls on the ANE
(MLComputePlan `ane>0`), unlike naive B1? If yes → the ANE-draft ∥ GPU-verify hybrid (B2) is back on the table.
If no → the GPU fallback is deeper than dynamic indexing and B2 stays DECLINED (亏的不要, negative result saved).

Run:  /tmp/cml312/bin/python3 Tools/draft_llm_fixedwindow_stateful_to_coreml.py
Out:  /tmp/draft/FixedWindowStateful_fp16.mlpackage
Then: the Swift MLComputePlan/latency probe (autoregressive, host-fed onehot+bias) compares ANE vs GPU.
"""
import os

import numpy as np
import torch
import torch.nn as nn
import coremltools as ct

HIDDEN = 2048
N_LAYERS = 4
N_HEADS = 32
HEAD_DIM = 64
INTERMEDIATE = 8192
VOCAB = 32000
MAX_SEQ = 256
OUT_DIR = "/tmp/draft"


class RMSNorm(nn.Module):
    def __init__(self, dim: int) -> None:
        super().__init__()
        self.weight = nn.Parameter(torch.ones(dim))

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        return x * torch.rsqrt(x.pow(2).mean(-1, keepdim=True) + 1e-6) * self.weight


class FixedWindowStateful(nn.Module):
    """Decoder whose per-layer K/V caches are STATES, written by an elementwise one-hot select (no dynamic
    index) and masked by a host-supplied additive bias (no runtime compare).

    forward(hidden[1,1,H], write_onehot[MAX_SEQ], attn_bias[MAX_SEQ]) -> logits[1,1,VOCAB]."""

    def __init__(self) -> None:
        super().__init__()
        self.norm1 = nn.ModuleList([RMSNorm(HIDDEN) for _ in range(N_LAYERS)])
        self.norm2 = nn.ModuleList([RMSNorm(HIDDEN) for _ in range(N_LAYERS)])
        self.q = nn.ModuleList([nn.Linear(HIDDEN, N_HEADS * HEAD_DIM, bias=False) for _ in range(N_LAYERS)])
        self.k = nn.ModuleList([nn.Linear(HIDDEN, N_HEADS * HEAD_DIM, bias=False) for _ in range(N_LAYERS)])
        self.v = nn.ModuleList([nn.Linear(HIDDEN, N_HEADS * HEAD_DIM, bias=False) for _ in range(N_LAYERS)])
        self.o = nn.ModuleList([nn.Linear(N_HEADS * HEAD_DIM, HIDDEN, bias=False) for _ in range(N_LAYERS)])
        self.gate = nn.ModuleList([nn.Linear(HIDDEN, INTERMEDIATE, bias=False) for _ in range(N_LAYERS)])
        self.up = nn.ModuleList([nn.Linear(HIDDEN, INTERMEDIATE, bias=False) for _ in range(N_LAYERS)])
        self.down = nn.ModuleList([nn.Linear(INTERMEDIATE, HIDDEN, bias=False) for _ in range(N_LAYERS)])
        self.fnorm = RMSNorm(HIDDEN)
        self.lm_head = nn.Linear(HIDDEN, VOCAB, bias=False)
        # Per-layer K/V cache STATES, held in SEPARATE buffers so there is no layer-dim indexing in the graph.
        # Shape [1, N_HEADS, MAX_SEQ, HEAD_DIM].
        for li in range(N_LAYERS):
            self.register_buffer(f"k_cache_{li}", torch.zeros(1, N_HEADS, MAX_SEQ, HEAD_DIM))
            self.register_buffer(f"v_cache_{li}", torch.zeros(1, N_HEADS, MAX_SEQ, HEAD_DIM))

    def forward(
        self, hidden: torch.Tensor, write_onehot: torch.Tensor, attn_bias: torch.Tensor
    ) -> torch.Tensor:
        oh = write_onehot.view(1, 1, MAX_SEQ, 1)    # broadcast over heads + head_dim → selects the pos slot
        keep = 1.0 - oh
        bias = attn_bias.view(1, 1, 1, MAX_SEQ)     # additive causal mask (0 valid / -inf future)
        x = hidden
        for li in range(N_LAYERS):
            h = self.norm1[li](x)
            q = self.q[li](h).view(1, 1, N_HEADS, HEAD_DIM).transpose(1, 2)   # [1,H,1,D]
            k = self.k[li](h).view(1, 1, N_HEADS, HEAD_DIM).transpose(1, 2)   # [1,H,1,D]
            v = self.v[li](h).view(1, 1, N_HEADS, HEAD_DIM).transpose(1, 2)   # [1,H,1,D]
            kc = getattr(self, f"k_cache_{li}")     # [1,H,MAX_SEQ,D]
            vc = getattr(self, f"v_cache_{li}")
            # Elementwise one-hot write: put k/v into the pos slot, keep the rest. k [1,H,1,D] broadcasts over
            # MAX_SEQ; oh [1,1,MAX_SEQ,1] selects. No advanced indexing → ANE-friendly.
            kc_new = kc * keep + k * oh             # [1,H,MAX_SEQ,D]
            vc_new = vc * keep + v * oh
            # State write-back via a STATIC full-slice assignment. coremltools' `generate_tensor_assignment_ops`
            # pass maps a slice-assign to a state write (a functional `.copy_(...)` does NOT match). The slice is
            # the WHOLE tensor (`[:, :, :, :]`) → static, no dynamic position index (that was B1's ANE-killer).
            getattr(self, f"k_cache_{li}")[:, :, :, :] = kc_new
            getattr(self, f"v_cache_{li}")[:, :, :, :] = vc_new
            scores = (q @ kc_new.transpose(-1, -2)) * (HEAD_DIM ** -0.5)   # [1,H,1,MAX_SEQ]
            scores = scores + bias                  # additive mask, no runtime compare
            attn = torch.softmax(scores, dim=-1)
            out = (attn @ vc_new).transpose(1, 2).reshape(1, 1, N_HEADS * HEAD_DIM)
            x = x + self.o[li](out)
            h2 = self.norm2[li](x)
            x = x + self.down[li](torch.nn.functional.silu(self.gate[li](h2)) * self.up[li](h2))
        return self.lm_head(self.fnorm(x))


def main() -> None:
    os.makedirs(OUT_DIR, exist_ok=True)
    model = FixedWindowStateful().eval()
    hidden = torch.randn(1, 1, HIDDEN)
    write_onehot = torch.zeros(MAX_SEQ)
    write_onehot[0] = 1.0
    attn_bias = torch.zeros(MAX_SEQ)
    attn_bias[1:] = -1e4   # position 0 valid, rest masked (host supplies the real per-step bias)
    with torch.no_grad():
        traced = torch.jit.trace(model, (hidden, write_onehot, attn_bias))
    states = []
    for li in range(N_LAYERS):
        states.append(ct.StateType(
            wrapped_type=ct.TensorType(shape=(1, N_HEADS, MAX_SEQ, HEAD_DIM)), name=f"k_cache_{li}"))
        states.append(ct.StateType(
            wrapped_type=ct.TensorType(shape=(1, N_HEADS, MAX_SEQ, HEAD_DIM)), name=f"v_cache_{li}"))
    ml = ct.convert(
        traced,
        inputs=[
            ct.TensorType(name="hidden", shape=(1, 1, HIDDEN), dtype=np.float32),
            ct.TensorType(name="write_onehot", shape=(MAX_SEQ,), dtype=np.float32),
            ct.TensorType(name="attn_bias", shape=(MAX_SEQ,), dtype=np.float32),
        ],
        outputs=[ct.TensorType(name="logits", dtype=np.float32)],
        states=states,
        minimum_deployment_target=ct.target.iOS18,
        compute_units=ct.ComputeUnit.ALL,
        compute_precision=ct.precision.FLOAT16,
        convert_to="mlprogram",
    )
    out = f"{OUT_DIR}/FixedWindowStateful_fp16.mlpackage"
    ml.save(out)
    print(f">> FIXED-WINDOW STATEFUL saved {out}")


if __name__ == "__main__":
    main()
