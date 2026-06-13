#!/usr/bin/env python3
"""B0 — ANE-placement feasibility gate for a CoreAI/ANE LLM speculative-decode DRAFT.

The decisive, cheapest experiment behind the operator's challenge ("CoreAI 怎么可能不能参与 decode"):
does a fp16 transformer at DECODE shape (single-token GEMVs + lm_head — the bandwidth-bound matmuls that
dominate autoregressive decode) get its ops PLANNED onto the Apple Neural Engine by CoreML?

This converts a SYNTHETIC same-shape-as-a-real-small-draft decoder block (raw torch, no transformers/HF
dependency) to a CoreML mlprogram at fp16. It isolates the ANE-placement question from full-model
conversion complexity (rotary/GQA/KV-state/tokenizer = B1). If even this clean block's matmul/attention
ops land on ANE → the door is open for a real draft (B1/B2). If not → ANE won't take transformer decode →
DECLINE with data.

Run:  scripts/PhaseB_ContextClassifier/venv/bin/python3 Tools/draft_llm_to_coreml.py
Out:  /tmp/draft/DraftBlock.mlpackage   (+ a fp32 control alongside)
Then: the Swift MLComputePlan probe walks per-op compute-device placement (ane=N?).
"""
import sys
import numpy as np
import torch
import torch.nn as nn
import coremltools as ct

# Llama-3.2-1B-ish shapes (the real draft target), at DECODE shape (seq=1).
HIDDEN = 2048
N_LAYERS = 4          # a few layers — enough to see placement; not the full 16 (keeps convert fast)
N_HEADS = 32
HEAD_DIM = 64         # 32*64 = 2048
INTERMEDIATE = 8192
VOCAB = 32000
SEQ = 1               # DECODE shape: one token. The matmuls are M=1 GEMV — the bandwidth-bound decode regime.
OUT_DIR = "/tmp/draft"


class RMSNorm(nn.Module):
    def __init__(self, dim):
        super().__init__()
        self.weight = nn.Parameter(torch.ones(dim))

    def forward(self, x):
        var = x.pow(2).mean(-1, keepdim=True)
        return x * torch.rsqrt(var + 1e-6) * self.weight


class Attn(nn.Module):
    def __init__(self):
        super().__init__()
        self.q = nn.Linear(HIDDEN, N_HEADS * HEAD_DIM, bias=False)
        self.k = nn.Linear(HIDDEN, N_HEADS * HEAD_DIM, bias=False)
        self.v = nn.Linear(HIDDEN, N_HEADS * HEAD_DIM, bias=False)
        self.o = nn.Linear(N_HEADS * HEAD_DIM, HIDDEN, bias=False)

    def forward(self, x):
        b, s, _ = x.shape
        q = self.q(x).view(b, s, N_HEADS, HEAD_DIM).transpose(1, 2)
        k = self.k(x).view(b, s, N_HEADS, HEAD_DIM).transpose(1, 2)
        v = self.v(x).view(b, s, N_HEADS, HEAD_DIM).transpose(1, 2)
        scores = (q @ k.transpose(-1, -2)) * (HEAD_DIM ** -0.5)
        attn = torch.softmax(scores, dim=-1)
        out = (attn @ v).transpose(1, 2).reshape(b, s, N_HEADS * HEAD_DIM)
        return self.o(out)


class MLP(nn.Module):
    def __init__(self):
        super().__init__()
        self.gate = nn.Linear(HIDDEN, INTERMEDIATE, bias=False)
        self.up = nn.Linear(HIDDEN, INTERMEDIATE, bias=False)
        self.down = nn.Linear(INTERMEDIATE, HIDDEN, bias=False)

    def forward(self, x):
        return self.down(torch.nn.functional.silu(self.gate(x)) * self.up(x))


class Layer(nn.Module):
    def __init__(self):
        super().__init__()
        self.n1 = RMSNorm(HIDDEN)
        self.attn = Attn()
        self.n2 = RMSNorm(HIDDEN)
        self.mlp = MLP()

    def forward(self, x):
        x = x + self.attn(self.n1(x))
        x = x + self.mlp(self.n2(x))
        return x


class DraftBlock(nn.Module):
    """N decoder layers + final norm + lm_head — the decode matmul surface."""
    def __init__(self):
        super().__init__()
        self.layers = nn.ModuleList([Layer() for _ in range(N_LAYERS)])
        self.norm = RMSNorm(HIDDEN)
        self.lm_head = nn.Linear(HIDDEN, VOCAB, bias=False)

    def forward(self, x):
        for layer in self.layers:
            x = layer(x)
        return self.lm_head(self.norm(x))


def convert(precision, tag):
    model = DraftBlock().eval()
    example = torch.randn(1, SEQ, HIDDEN)
    with torch.no_grad():
        traced = torch.jit.trace(model, example)
    ml = ct.convert(
        traced,
        inputs=[ct.TensorType(name="hidden", shape=(1, SEQ, HIDDEN), dtype=np.float32)],
        outputs=[ct.TensorType(name="logits", dtype=np.float32)],
        minimum_deployment_target=ct.target.iOS18,
        compute_units=ct.ComputeUnit.ALL,
        compute_precision=precision,
        convert_to="mlprogram",
    )
    out = f"{OUT_DIR}/DraftBlock_{tag}.mlpackage"
    ml.save(out)
    # Numerical sanity: run the CoreML model + compare argmax to torch (catch fp16 NaN).
    pred = ml.predict({"hidden": example.numpy()})
    logits = np.array(list(pred.values())[0]).reshape(-1)
    nan = bool(np.isnan(logits).any())
    with torch.no_grad():
        ref = model(example).numpy().reshape(-1)
    argmax_match = int(np.argmax(logits)) == int(np.argmax(ref))
    mae = float(np.mean(np.abs(logits - ref)))
    print(f">> {tag}: saved {out}  nan={nan}  argmax_match={argmax_match}  mae={mae:.4g}")
    return out


if __name__ == "__main__":
    import os
    os.makedirs(OUT_DIR, exist_ok=True)
    print(f">> DraftBlock shapes: hidden={HIDDEN} layers={N_LAYERS} heads={N_HEADS} "
          f"intermediate={INTERMEDIATE} vocab={VOCAB} seq={SEQ} (decode shape)")
    convert(ct.precision.FLOAT16, "fp16")   # the ANE-relevant precision
    convert(ct.precision.FLOAT32, "fp32")   # control (planner usually keeps fp32 off ANE)
    print(">> done. Next: run the Swift MLComputePlan probe on /tmp/draft/DraftBlock_fp16.mlpackage")
