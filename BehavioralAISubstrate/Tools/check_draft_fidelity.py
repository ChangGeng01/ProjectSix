#!/usr/bin/env python3
"""B2 — fidelity of a converted Llama-1B Core ML draft (fp16 or int4) vs HF greedy, run through actual Core ML.

The converter's in-flow fp16 re-check certifies the fp16 artifact at conversion time; this standalone checker
runs ANY saved mlpackage (fp16 OR the int4-quantized draft) through the real stateful Core ML predict loop and
reports token-match against HF Llama-1B greedy. For the int4 draft this is the honest quantization-fidelity
number (quantization lowers ACCEPTANCE, not correctness — the 3B target verify still guarantees output, but a
low-fidelity draft means a low speedup).

Run:  /tmp/cml312/bin/python3 Tools/check_draft_fidelity.py <mlpackage> [hf_model] [n_new]
"""
import sys

import numpy as np
import torch
import coremltools as ct
from transformers import AutoModelForCausalLM, AutoTokenizer

MLPKG = sys.argv[1] if len(sys.argv) > 1 else "/tmp/draft/LlamaDraft1B_int4.mlpackage"
MODEL = sys.argv[2] if len(sys.argv) > 2 else "unsloth/Llama-3.2-1B-Instruct"
REVISION = "5a8abab4a5d6f164389b1079fb721cfab8d7126c" if MODEL == "unsloth/Llama-3.2-1B-Instruct" else None
N_NEW = int(sys.argv[3]) if len(sys.argv) > 3 else 24
MAX_SEQ = 512
PROMPT = "The capital of France is"


def main() -> None:
    print(f">> loading {MODEL} (reference) + {MLPKG}")
    hf = AutoModelForCausalLM.from_pretrained(MODEL, revision=REVISION, dtype=torch.float32).eval()
    tok = AutoTokenizer.from_pretrained(MODEL, revision=REVISION)
    rotary = hf.model.rotary_emb
    hidden = hf.config.hidden_size

    def cos_sin(pos: int):
        pid = torch.tensor([[pos]], dtype=torch.long)
        cos, sin = rotary(torch.zeros(1, 1, hidden), pid)
        return cos[0, 0].numpy().astype(np.float32), sin[0, 0].numpy().astype(np.float32)

    ids = tok(PROMPT, return_tensors="pt").input_ids
    with torch.no_grad():
        hf_out = hf.generate(ids, max_new_tokens=N_NEW, do_sample=False, use_cache=True,
                             pad_token_id=tok.eos_token_id)
    hf_new = hf_out[0, ids.shape[1]:].tolist()

    cm = ct.models.MLModel(MLPKG)
    state = cm.make_state()

    def step(tid: int, pos: int):
        c, s = cos_sin(pos)
        oh = np.zeros(MAX_SEQ, dtype=np.float32); oh[pos] = 1.0
        bias = np.zeros(MAX_SEQ, dtype=np.float32); bias[pos + 1:] = -1e4
        out = cm.predict({
            "input_id": np.array([[tid]], dtype=np.int32),
            "rope_cos": c, "rope_sin": s, "write_onehot": oh, "attn_bias": bias,
        }, state=state)
        return np.asarray(out["logits"]).reshape(-1)

    pos = 0
    for t in ids[0].tolist():
        lg = step(t, pos); pos += 1
    cm_new = []
    nxt = int(lg.argmax())
    for _ in range(N_NEW):
        cm_new.append(nxt); lg = step(nxt, pos); pos += 1; nxt = int(lg.argmax())

    match = sum(1 for a, b in zip(hf_new, cm_new) if a == b)
    name = MLPKG.split("/")[-1]
    print(f">> {name} hf_new   ={hf_new}")
    print(f">> {name} coreml   ={cm_new}")
    print(f">> {name} token_match={match}/{N_NEW}  text={tok.decode(cm_new)!r}")


if __name__ == "__main__":
    main()
