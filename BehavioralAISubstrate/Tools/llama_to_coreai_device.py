#!/usr/bin/env python3
"""Build the fp16 Llama-3.2-1B → .aimodel DEVICE artifact for the Phase-0 THROUGHPUT gate.

Throughput / memory / ANE-placement are FIDELITY-INDEPENDENT — a same-shape model measures the
same tok/s, peak MB, and op placement regardless of the known coreai_torch-0.4.0 attention-value
matmul bug (see Tools/llama_to_coreai.py). So this skips the (slow) host fidelity recheck and just
emits the small fp16 artifact that fits the A19 jetsam cap (fp32 was 4.6 GB > cap).

Run:  /tmp/coreai-cv/bin/python Tools/llama_to_coreai_device.py
Out:  /tmp/draft_coreai/LlamaDraft1B_fp16.aimodel
"""
import sys
import torch
sys.path.insert(0, "Tools")
from llama_to_coreai import StatefulLlamaDraft, copy_weights, convert_to_aimodel, MODEL, REVISION

OUT = "/tmp/draft_coreai/LlamaDraft1B_fp16.aimodel"


def main() -> None:
    from transformers import AutoModelForCausalLM
    print(f">> loading {MODEL} (revision={REVISION}) for fp16 device artifact")
    hf = AutoModelForCausalLM.from_pretrained(MODEL, revision=REVISION, dtype=torch.float32).eval()
    draft = StatefulLlamaDraft(hf.config).eval()
    copy_weights(draft, hf)
    draft = draft.half()    # fp16 weights + fp16 fused KV buffer
    print(">> converting fp16 → .aimodel (fidelity-imperfect by design — throughput gate)")
    convert_to_aimodel(draft, OUT, dtype=torch.float16)
    import os
    sz = sum(os.path.getsize(os.path.join(OUT, f)) for f in os.listdir(OUT)) / 1e9
    print(f">> DEVICE ARTIFACT {OUT}  size={sz:.2f} GB  (cap 3.25 GB; KV fp16 ~17 MB)")


if __name__ == "__main__":
    main()
