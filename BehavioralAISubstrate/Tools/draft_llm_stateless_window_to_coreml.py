#!/usr/bin/env python3
"""B1'' — STATELESS windowed-recompute decoder (the door B1/B1' left open for ANE decode).

B0: a STATELESS fp16 transformer block plans 100% onto the ANE. B1 (naive stateful) + B1' (fixed-window
stateful, elementwise, no dynamic index) BOTH plan 100% onto the GPU — so the GPU fallback is triggered by the
iOS18 STATE mechanism itself, not by dynamic indexing. This formulation removes state ENTIRELY: instead of a
persistent KV cache, each decode step feeds the last W token hidden states as a fixed-shape input `[1, W, H]`
and recomputes causal self-attention over the window (a static baked causal mask — no runtime input, no state).

Trade: O(W) recompute per token instead of O(1) KV-cache decode — but if it inherits B0's 100% ANE placement,
that recompute runs on the OTHERWISE-IDLE ANE in PARALLEL with the GPU verify (the actual "压榨 CoreAI" hybrid),
and a single `[1, W, H]` forward is one efficient ANE call (NOT W separate steps). Decisive question (measured):
does the stateless windowed graph plan onto the ANE (`ane>0`), unlike every stateful formulation?

Run:  /tmp/cml312/bin/python3 Tools/draft_llm_stateless_window_to_coreml.py
Out:  /tmp/draft/StatelessWindow_fp16.mlpackage
Then: Tools/stateless_window_ane_probe.swift walks MLComputePlan + per-draft-token latency (ANE vs GPU).
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
WINDOW = 64
OUT_DIR = "/tmp/draft"


class RMSNorm(nn.Module):
    def __init__(self, dim: int) -> None:
        super().__init__()
        self.weight = nn.Parameter(torch.ones(dim))

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        return x * torch.rsqrt(x.pow(2).mean(-1, keepdim=True) + 1e-6) * self.weight


class StatelessWindow(nn.Module):
    """Windowed-recompute decoder. forward(hidden_window[1,W,H]) -> logits[1,VOCAB] (last position only).

    No state, no dynamic index — a static baked causal mask over the fixed window W. Stateless + fixed-shape,
    the shape B0 proved the ANE planner accepts."""

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
        # Static causal mask over the fixed window: [1,1,W,W], 0 on/below diagonal, -inf above. A baked constant.
        mask = torch.triu(torch.full((WINDOW, WINDOW), float("-inf")), diagonal=1)
        self.register_buffer("causal_mask", mask.view(1, 1, WINDOW, WINDOW))

    def forward(self, hidden_window: torch.Tensor) -> torch.Tensor:
        x = hidden_window   # [1, W, H]
        for li in range(N_LAYERS):
            h = self.norm1[li](x)
            q = self.q[li](h).view(1, WINDOW, N_HEADS, HEAD_DIM).transpose(1, 2)   # [1,Hn,W,D]
            k = self.k[li](h).view(1, WINDOW, N_HEADS, HEAD_DIM).transpose(1, 2)
            v = self.v[li](h).view(1, WINDOW, N_HEADS, HEAD_DIM).transpose(1, 2)
            scores = (q @ k.transpose(-1, -2)) * (HEAD_DIM ** -0.5)   # [1,Hn,W,W]
            scores = scores + self.causal_mask
            attn = torch.softmax(scores, dim=-1)
            out = (attn @ v).transpose(1, 2).reshape(1, WINDOW, N_HEADS * HEAD_DIM)
            x = x + self.o[li](out)
            h2 = self.norm2[li](x)
            x = x + self.down[li](torch.nn.functional.silu(self.gate[li](h2)) * self.up[li](h2))
        logits = self.lm_head(self.fnorm(x))     # [1, W, VOCAB]
        return logits[:, -1, :]                  # only the last position's next-token logits → [1, VOCAB]


def main() -> None:
    os.makedirs(OUT_DIR, exist_ok=True)
    model = StatelessWindow().eval()
    hidden_window = torch.randn(1, WINDOW, HIDDEN)
    with torch.no_grad():
        traced = torch.jit.trace(model, (hidden_window,))
    ml = ct.convert(
        traced,
        inputs=[ct.TensorType(name="hidden_window", shape=(1, WINDOW, HIDDEN), dtype=np.float32)],
        outputs=[ct.TensorType(name="logits", dtype=np.float32)],
        minimum_deployment_target=ct.target.iOS17,
        compute_units=ct.ComputeUnit.ALL,
        compute_precision=ct.precision.FLOAT16,
        convert_to="mlprogram",
    )
    out = f"{OUT_DIR}/StatelessWindow_fp16.mlpackage"
    ml.save(out)
    print(f">> STATELESS-WINDOW saved {out}")


if __name__ == "__main__":
    main()
