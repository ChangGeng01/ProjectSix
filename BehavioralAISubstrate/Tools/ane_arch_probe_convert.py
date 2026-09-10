#!/usr/bin/env python3
"""B-track Part B — parametrized Core ML converter to MAP the ANE/GPU boundary.

B0..B1'' established: stateless single-token feed-forward → ANE; attention-over-history (stateful OR recomputed,
seq>1) → GPU. This converter builds a SPECIFIED small architecture at fp16 so a placement probe can (i) confirm
the constructive side — attention-LIGHT heads (MLP, mean-pooled MLP) land on the ANE (the honest "压榨 CoreAI
where it shines": embedding / classification / projection heads), and (ii) pin the seq-length CROSSOVER where a
self-attention block flips ANE→GPU (sharpening the wall from a binary into a threshold).

Usage:  /tmp/cml312/bin/python3 Tools/ane_arch_probe_convert.py <arch> <out.mlpackage>
  arch ∈ { mlp | mlp_pool:<S> | attn:<S> }   (S = sequence length)
Examples:  mlp   mlp_pool:64   attn:1   attn:4   attn:16   attn:64   attn:128   attn:256
"""
import os
import sys

import numpy as np
import torch
import torch.nn as nn
import coremltools as ct

HIDDEN = 2048
N_HEADS = 32
HEAD_DIM = 64
INTERMEDIATE = 8192
VOCAB = 32000


class RMSNorm(nn.Module):
    def __init__(self, dim: int) -> None:
        super().__init__()
        self.weight = nn.Parameter(torch.ones(dim))

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        return x * torch.rsqrt(x.pow(2).mean(-1, keepdim=True) + 1e-6) * self.weight


class MLPHead(nn.Module):
    """Pure feed-forward head (no attention), single token. forward([1,1,H]) -> [1,VOCAB]."""

    def __init__(self) -> None:
        super().__init__()
        self.norm = RMSNorm(HIDDEN)
        self.gate = nn.Linear(HIDDEN, INTERMEDIATE, bias=False)
        self.up = nn.Linear(HIDDEN, INTERMEDIATE, bias=False)
        self.down = nn.Linear(INTERMEDIATE, HIDDEN, bias=False)
        self.lm_head = nn.Linear(HIDDEN, VOCAB, bias=False)

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        h = self.norm(x)
        x = x + self.down(torch.nn.functional.silu(self.gate(h)) * self.up(h))
        return self.lm_head(x)[:, -1, :]


class MLPPool(nn.Module):
    """Mean-pool over the sequence (reduction, NOT attention) then MLP. forward([1,S,H]) -> [1,VOCAB]."""

    def __init__(self) -> None:
        super().__init__()
        self.norm = RMSNorm(HIDDEN)
        self.gate = nn.Linear(HIDDEN, INTERMEDIATE, bias=False)
        self.up = nn.Linear(HIDDEN, INTERMEDIATE, bias=False)
        self.down = nn.Linear(INTERMEDIATE, HIDDEN, bias=False)
        self.lm_head = nn.Linear(HIDDEN, VOCAB, bias=False)

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        pooled = x.mean(dim=1, keepdim=True)    # [1,1,H] — reduction over seq, no attention
        h = self.norm(pooled)
        y = pooled + self.down(torch.nn.functional.silu(self.gate(h)) * self.up(h))
        return self.lm_head(y)[:, -1, :]


class AttnBlock(nn.Module):
    """One self-attention layer + MLP over a fixed seq (static causal mask). forward([1,S,H]) -> [1,VOCAB]."""

    def __init__(self, seq: int) -> None:
        super().__init__()
        self.seq = seq
        self.norm1 = RMSNorm(HIDDEN)
        self.norm2 = RMSNorm(HIDDEN)
        self.q = nn.Linear(HIDDEN, N_HEADS * HEAD_DIM, bias=False)
        self.k = nn.Linear(HIDDEN, N_HEADS * HEAD_DIM, bias=False)
        self.v = nn.Linear(HIDDEN, N_HEADS * HEAD_DIM, bias=False)
        self.o = nn.Linear(N_HEADS * HEAD_DIM, HIDDEN, bias=False)
        self.gate = nn.Linear(HIDDEN, INTERMEDIATE, bias=False)
        self.up = nn.Linear(HIDDEN, INTERMEDIATE, bias=False)
        self.down = nn.Linear(INTERMEDIATE, HIDDEN, bias=False)
        self.lm_head = nn.Linear(HIDDEN, VOCAB, bias=False)
        mask = torch.triu(torch.full((seq, seq), float("-inf")), diagonal=1)
        self.register_buffer("causal_mask", mask.view(1, 1, seq, seq))

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        S = self.seq
        h = self.norm1(x)
        q = self.q(h).view(1, S, N_HEADS, HEAD_DIM).transpose(1, 2)
        k = self.k(h).view(1, S, N_HEADS, HEAD_DIM).transpose(1, 2)
        v = self.v(h).view(1, S, N_HEADS, HEAD_DIM).transpose(1, 2)
        scores = (q @ k.transpose(-1, -2)) * (HEAD_DIM ** -0.5) + self.causal_mask
        attn = torch.softmax(scores, dim=-1)
        out = (attn @ v).transpose(1, 2).reshape(1, S, N_HEADS * HEAD_DIM)
        x = x + self.o(out)
        h2 = self.norm2(x)
        x = x + self.down(torch.nn.functional.silu(self.gate(h2)) * self.up(h2))
        return self.lm_head(x)[:, -1, :]


def build(arch: str):
    if arch == "mlp":
        return MLPHead().eval(), (1, 1, HIDDEN)
    if arch.startswith("mlp_pool:"):
        s = int(arch.split(":")[1])
        return MLPPool().eval(), (1, s, HIDDEN)
    if arch.startswith("attn:"):
        s = int(arch.split(":")[1])
        return AttnBlock(s).eval(), (1, s, HIDDEN)
    raise SystemExit(f"unknown arch '{arch}'")


def main() -> None:
    if len(sys.argv) < 3:
        raise SystemExit("usage: ane_arch_probe_convert.py <arch> <out.mlpackage>")
    arch, out = sys.argv[1], sys.argv[2]
    os.makedirs(os.path.dirname(out) or ".", exist_ok=True)
    model, shape = build(arch)
    sample = torch.randn(*shape)
    with torch.no_grad():
        traced = torch.jit.trace(model, (sample,))
    ml = ct.convert(
        traced,
        inputs=[ct.TensorType(name="x", shape=shape, dtype=np.float32)],
        outputs=[ct.TensorType(name="logits", dtype=np.float32)],
        minimum_deployment_target=ct.target.iOS17,
        compute_units=ct.ComputeUnit.ALL,
        compute_precision=ct.precision.FLOAT16,
        convert_to="mlprogram",
    )
    ml.save(out)
    print(f">> {arch} saved {out}")


if __name__ == "__main__":
    main()
