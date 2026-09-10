#!/usr/bin/env python3
"""Head-split fix for the ANE InvalidWidth wall (vocab 248320 > ANE max width):
asset3body = layers 24-31 + final norm, hidden->hidden (ANE-safe); head_only = tied int8 head (GPU/default).
Both keep a state_all (head's is a dummy [1,ROW]) so the device probe's single-state path works unchanged."""
import sys, shutil
from pathlib import Path
import torch, torch.nn as nn
sys.path.insert(0, "/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tools")
from qwen35_realweights_to_coreai import load_st, raw, dequant, rms, D
from qwen35_3asset_fused import FusedAsset, ROW
from qwen35_fixed_decode import NB
from llama_to_coreai_int8 import QuantLinear
import coreai_torch
from coreai_torch._compression.utils import inject_subbyte_tensors
P = "language_model.model."

class Asset3Body(FusedAsset):
    def __init__(s, st):
        super().__init__(st, 24, 32, head=False)          # 8 layers, hidden->hidden
        s.fn = raw(st, P + "norm.weight").half()
    def forward(s, x):
        h = super().forward(x)                            # [1,D]
        return rms(h.view(D), s.fn).view(1, D)            # apply final norm here (head asset is pure matmul)

class HeadOnly(nn.Module):
    def __init__(s, st):
        super().__init__()
        s.head = QuantLinear(dequant(st, P + "embed_tokens").float(), NB)
        s.register_buffer("state_all", torch.zeros(1, ROW, dtype=torch.float16))  # dummy: probe contract
    def forward(s, x):
        s.state_all[:] = s.state_all                       # keep the buffer mutated so it stays a state
        return s.head(x.view(D)).view(1, -1)

def convert(m, name):
    ep = torch.export.export(m.eval(), (torch.zeros(1, D, dtype=torch.float16),))
    ep = ep.run_decompositions(coreai_torch.get_decomp_table()); ep = inject_subbyte_tensors(ep)
    states = list(ep.graph_signature.buffers_to_mutate.values()); assert states == ["state_all"], states
    conv = coreai_torch.TorchConverter().add_exported_program(ep, input_names=["x"], output_names=["out"], state_names=states, entrypoint_name="main")
    prog = conv.to_coreai(); prog.optimize()
    out = f"/tmp/gdn_coreai/{name}.aimodel"
    if Path(out).exists(): shutil.rmtree(out)
    prog.save_asset(Path(out))
    print(f">> ✅ {name}: {(Path(out)/'main.mlirb').stat().st_size/1e9:.2f} GB")

st = load_st()
convert(Asset3Body(st), "Qwen35fused_asset3body_int8")
convert(HeadOnly(st), "Qwen35fused_head_only_int8")
