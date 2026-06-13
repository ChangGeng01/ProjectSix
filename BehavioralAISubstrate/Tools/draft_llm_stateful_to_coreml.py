#!/usr/bin/env python3
"""B1 — stateful Core ML KV-cache decoder (the gating piece for the ANE-draft hybrid).

B0 proved fp16 transformer decode plans 100% onto the ANE and the A19 ANE per-token latency ≈ GPU. B1's new
question: can a STATEFUL transformer (iOS18 KV-cache via `ct.StateType`) — the thing a real autoregressive
ANE decode loop needs — be converted + run on the ANE? This converts a small Llama-shaped decoder whose
per-layer K/V caches are persistent STATES, with `forward(hidden, position)` writing the new token's K/V into
the cache at `position` and attending over the valid prefix.

Run:  /tmp/cml312/bin/python3 Tools/draft_llm_stateful_to_coreml.py
Out:  /tmp/draft/StatefulDraft_fp16.mlpackage
Then: the Swift MLComputePlan/latency probe (autoregressive) measures ANE per-step decode with the live state.
"""
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
    def __init__(self, dim):
        super().__init__()
        self.weight = nn.Parameter(torch.ones(dim))

    def forward(self, x):
        return x * torch.rsqrt(x.pow(2).mean(-1, keepdim=True) + 1e-6) * self.weight


class StatefulDraft(nn.Module):
    """Decoder with per-layer K/V cache STATES. forward(hidden[1,1,H], position[1]) → logits[1,1,VOCAB]."""
    def __init__(self):
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
        # KV-cache STATES: [N_LAYERS, 1, N_HEADS, MAX_SEQ, HEAD_DIM]
        self.register_buffer("k_cache", torch.zeros(N_LAYERS, 1, N_HEADS, MAX_SEQ, HEAD_DIM))
        self.register_buffer("v_cache", torch.zeros(N_LAYERS, 1, N_HEADS, MAX_SEQ, HEAD_DIM))

    def forward(self, hidden, position):
        pos = position  # int tensor [1]
        x = hidden
        for li in range(N_LAYERS):
            h = self.norm1[li](x)
            q = self.q[li](h).view(1, 1, N_HEADS, HEAD_DIM).transpose(1, 2)   # [1,H,1,D]
            k = self.k[li](h).view(1, 1, N_HEADS, HEAD_DIM).transpose(1, 2)
            v = self.v[li](h).view(1, 1, N_HEADS, HEAD_DIM).transpose(1, 2)
            # Write the new K/V into the cache at `pos` (in-place state update). k/v are [1,H,1,D]; the indexed
            # LHS k_cache[li,:,:,pos,:] is also [1,H,1,D] (pos is a 1-elem tensor → keeps the size-1 dim).
            self.k_cache[li, :, :, pos, :] = k
            self.v_cache[li, :, :, pos, :] = v
            kc = self.k_cache[li]   # [1,H,MAX_SEQ,D]
            vc = self.v_cache[li]
            scores = (q @ kc.transpose(-1, -2)) * (HEAD_DIM ** -0.5)   # [1,H,1,MAX_SEQ]
            # causal mask: only attend to positions <= pos
            idx = torch.arange(MAX_SEQ)
            mask = (idx <= pos).view(1, 1, 1, MAX_SEQ)
            scores = scores.masked_fill(~mask, float("-inf"))
            attn = torch.softmax(scores, dim=-1)
            out = (attn @ vc).transpose(1, 2).reshape(1, 1, N_HEADS * HEAD_DIM)
            x = x + self.o[li](out)
            h2 = self.norm2[li](x)
            x = x + self.down[li](torch.nn.functional.silu(self.gate[li](h2)) * self.up[li](h2))
        return self.lm_head(self.fnorm(x))


def main():
    import os
    os.makedirs(OUT_DIR, exist_ok=True)
    model = StatefulDraft().eval()
    hidden = torch.randn(1, 1, HIDDEN)
    position = torch.tensor([0], dtype=torch.int32)
    with torch.no_grad():
        traced = torch.jit.trace(model, (hidden, position))
    ml = ct.convert(
        traced,
        inputs=[
            ct.TensorType(name="hidden", shape=(1, 1, HIDDEN), dtype=np.float32),
            ct.TensorType(name="position", shape=(1,), dtype=np.int32),
        ],
        outputs=[ct.TensorType(name="logits", dtype=np.float32)],
        states=[
            ct.StateType(wrapped_type=ct.TensorType(shape=(N_LAYERS, 1, N_HEADS, MAX_SEQ, HEAD_DIM)), name="k_cache"),
            ct.StateType(wrapped_type=ct.TensorType(shape=(N_LAYERS, 1, N_HEADS, MAX_SEQ, HEAD_DIM)), name="v_cache"),
        ],
        minimum_deployment_target=ct.target.iOS18,
        compute_units=ct.ComputeUnit.ALL,
        compute_precision=ct.precision.FLOAT16,
        convert_to="mlprogram",
    )
    out = f"{OUT_DIR}/StatefulDraft_fp16.mlpackage"
    ml.save(out)
    print(f">> STATEFUL saved {out}")


if __name__ == "__main__":
    main()
