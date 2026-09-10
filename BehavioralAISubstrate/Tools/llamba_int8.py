#!/usr/bin/env python3
"""int8 weight-quantized Llamba-1B (Mamba-2) → CoreAI .aimodel — to get UNDER the CoreAI-0.4.0 beta ~2GB
asset-load limit that bad_alloc-crashed the 2.6GB fp16 Mamba on ALL A19 backends. At ~1.3GB the 16-layer
int8 Mamba can actually LOAD, so the real Q1 question — does 16 RECURRENT layers clear the per-asset ANE
compile ceiling (where the 16-layer transformer SIGABRT'd)? — can finally be asked on device.

Reuses the proven int8 idiom (Tools/llama_to_coreai_int8.py: QuantLinear / QuantEmbed via
coreai::constexpr_blockwise_shift_scale, per-output-channel symmetric int8) applied to the Mamba model
(Tools/llamba_to_coreai.py: LlambaDecode). conv1d / z_bias / D / layernorms stay fp16 (small).

Run from /tmp:  cd /tmp && /tmp/coreai-cv/bin/python /tmp/llamba_int8.py
"""
from __future__ import annotations

import json
import shutil
import sys
import time
from pathlib import Path

import torch
import torch.nn.functional as F

TOOLS = "/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tools"
sys.path.insert(0, TOOLS)

import coreai_torch
from coreai_torch._compression.custom_layers import constexpr_blockwise_shift_scale  # noqa: F401 (registers op)
from coreai_torch._compression.utils import inject_subbyte_tensors

import llamba_to_coreai as L
from llama_to_coreai_int8 import QuantLinear, QuantEmbed   # the int8 machinery

OUT = "/tmp/draft_coreai/Llamba1B_int8.aimodel"
NBITS = 8


class QuantLlambaDecode(L.LlambaDecode):
    """LlambaDecode with every weight matrix int8-quantized; forward overridden so the tied lm_head reads the
    dequantized embed table (the base class did `x @ self.embedding.weight.t()`)."""

    def quantize(self, nbits: int = NBITS) -> "QuantLlambaDecode":
        for layer in self.layers:
            layer.in_proj = QuantLinear(layer.in_proj.weight, nbits)
            layer.out_proj = QuantLinear(layer.out_proj.weight, nbits)
            layer.gate_proj = QuantLinear(layer.gate_proj.weight, nbits)
            layer.up_proj = QuantLinear(layer.up_proj.weight, nbits)
            layer.down_proj = QuantLinear(layer.down_proj.weight, nbits)
        self.embedding = QuantEmbed(self.embedding.weight, nbits)
        return self

    def forward(self, input_id: torch.Tensor) -> torch.Tensor:
        embed_w = self.embedding.weight_fp16()                 # dequant once → lookup + tied lm_head
        x = F.embedding(input_id, embed_w).view(self.cfg.d_model)
        conv_all, ssm_all = self.conv_all, self.ssm_all
        new_conv: list[torch.Tensor] = []
        new_ssm: list[torch.Tensor] = []
        for i, layer in enumerate(self.layers):
            x, nc, ns = layer(x, conv_all[i], ssm_all[i])
            new_conv.append(nc)
            new_ssm.append(ns)
        self.conv_all[:] = torch.stack(new_conv, 0)
        self.ssm_all[:] = torch.stack(new_ssm, 0)
        x = L.rmsnorm(x, self.final_layernorm, self.cfg.norm_epsilon)
        return (x @ embed_w.to(x.dtype).t()).view(1, self.cfg.vocab_size)


def main() -> None:
    from huggingface_hub import hf_hub_download
    from safetensors.torch import load_file

    torch.manual_seed(0)
    print(f"=== int8 Llamba-1B (Mamba-2) → {OUT} (target <2GB so it LOADS on the A19) ===")
    cfg = L.cfg_from_json(json.load(open(hf_hub_download(L.HF_ID, "config.json"))))
    state = load_file(hf_hub_download(L.HF_ID, "model.safetensors"))

    model = QuantLlambaDecode(cfg).eval()
    L.load_real_weights(model, state)
    model.quantize(NBITS)
    model = model.half()
    print("    quantized int8 + fp16 residuals")

    t0 = time.time()
    sample = (torch.zeros(1, 1, dtype=torch.long),)
    ep = torch.export.export(model.eval(), sample)
    ep = ep.run_decompositions(coreai_torch.get_decomp_table())
    ep = inject_subbyte_tensors(ep)                            # no-op for int8, packs for int4
    state_names = list(ep.graph_signature.buffers_to_mutate.values())
    print(f"    {len(state_names)} states: {state_names}")
    conv = coreai_torch.TorchConverter().add_exported_program(
        ep, input_names=["input_id"], output_names=["logits"],
        state_names=state_names, entrypoint_name="main")
    prog = conv.to_coreai()
    prog.optimize()
    if Path(OUT).exists():
        shutil.rmtree(OUT)
    Path(OUT).parent.mkdir(parents=True, exist_ok=True)
    prog.save_asset(Path(OUT))
    sz = (Path(OUT) / "main.mlirb").stat().st_size
    print(f">> SAVED {OUT}  main.mlirb = {sz/1e9:.2f} GB  ({sz} bytes)  in {time.time()-t0:.0f}s")
    print(f">> {'✅ under 2GB — should LOAD' if sz < 2_000_000_000 else '⚠️ still ≥2GB'}")


if __name__ == "__main__":
    main()
