#!/usr/bin/env python3
"""B2 hybrid — emit the exact llama3 RoPE cos/sin tables so the Swift host feeds them per draft step.

The int8 Core ML draft takes rope_cos/rope_sin [head_dim] as INPUTS each step (exact, ANE-friendly). Rather than
re-implement llama3 RoPE scaling in Swift (error-prone), dump the precomputed tables [MAX_SEQ, head_dim] as raw
little-endian float32 from HF's own rotary embedding — Swift mmaps and indexes row `position`. Exact by construction.

Run:  /tmp/cml312/bin/python3 Tools/emit_rope_tables.py
Out:  /tmp/draft/rope_cos_f32.bin, rope_sin_f32.bin  ([MAX_SEQ, head_dim] row-major float32)
"""
import os

import numpy as np
import torch
from transformers import AutoModelForCausalLM

MODEL = "unsloth/Llama-3.2-1B-Instruct"
REVISION = "5a8abab4a5d6f164389b1079fb721cfab8d7126c"
MAX_SEQ = 512
OUT_DIR = "/tmp/draft"


def main() -> None:
    os.makedirs(OUT_DIR, exist_ok=True)
    hf = AutoModelForCausalLM.from_pretrained(MODEL, revision=REVISION, dtype=torch.float32).eval()
    rotary = hf.model.rotary_emb
    head_dim = hf.config.hidden_size // hf.config.num_attention_heads
    cos_rows, sin_rows = [], []
    for pos in range(MAX_SEQ):
        pid = torch.tensor([[pos]], dtype=torch.long)
        cos, sin = rotary(torch.zeros(1, 1, hf.config.hidden_size), pid)
        cos_rows.append(cos[0, 0].detach().numpy().astype(np.float32))
        sin_rows.append(sin[0, 0].detach().numpy().astype(np.float32))
    cos_t = np.stack(cos_rows)   # [MAX_SEQ, head_dim]
    sin_t = np.stack(sin_rows)
    assert cos_t.shape == (MAX_SEQ, head_dim), cos_t.shape
    cos_t.tofile(f"{OUT_DIR}/rope_cos_f32.bin")
    sin_t.tofile(f"{OUT_DIR}/rope_sin_f32.bin")
    print(f">> emitted rope tables [{MAX_SEQ}, {head_dim}] float32 → {OUT_DIR}/rope_{{cos,sin}}_f32.bin")


if __name__ == "__main__":
    main()
