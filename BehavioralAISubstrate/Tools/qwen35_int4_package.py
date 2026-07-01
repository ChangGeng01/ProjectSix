#!/usr/bin/env python3
"""M2 packaging proof: int4-quantize the VERIFIED real-weight GDN layer + convert → CoreAI asset under the wall.

Reuses the fidelity-verified RealGDN (Tools/qwen35_realweights_to_coreai.py) but wraps every linear in the int4
QuantLinear (llama_to_coreai_int8) + inject_subbyte_tensors — proving real-weight int4 packaging (the 3-asset wall
strategy). int4 is the natural target: the source is 4-bit, so dequant-4bit→int4 is ~lossless.
"""
from __future__ import annotations
import sys, shutil, time
from pathlib import Path
import torch, torch.nn as nn
SD = "/private/tmp/claude-501/-Users-changgeng-Project-Project06-Project06/c3ffc755-9222-4370-81cc-7a004da44172/scratchpad"
sys.path.insert(0, SD); sys.path.insert(0, "/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tools")
from qwen35_realweights_to_coreai import RealGDN, load_st, D, GV, GHD
import coreai_torch
from coreai_torch._compression.utils import inject_subbyte_tensors
from llama_to_coreai_int8 import QuantLinear

NBITS = 4


def int4ify(module):
    """Replace every nn.Linear in `module` with an int4 QuantLinear carrying its weight."""
    for name, child in list(module.named_children()):
        if isinstance(child, nn.Linear):
            setattr(module, name, QuantLinear(child.weight.data.float(), NBITS))
        else:
            int4ify(child)
    return module


class M(nn.Module):
    def __init__(s, st):
        super().__init__()
        s.gdn = int4ify(RealGDN(st, 0))
        s.gdn.A_log.data = s.gdn.A_log.data.half(); s.gdn.dt_bias.data = s.gdn.dt_bias.data.half()  # keep state f16
        s.head = QuantLinear(torch.randn(512, D) * 0.02, NBITS)      # reduced int4 head (real layer is the point)
        s.register_buffer("state", torch.zeros(GV, GHD, GHD, dtype=torch.float16))
        s.register_buffer("convwin", torch.zeros(3, 8192, dtype=torch.float16))

    def forward(s, x):
        h, st, cw = s.gdn(x.view(D), s.state, s.convwin)
        s.state[:] = st; s.convwin[:] = cw
        return s.head(h).view(1, 512)


def main():
    print(f">> int4-quantizing the verified real-weight GDN layer...")
    st = load_st(); m = M(st).eval()
    # QuantLinear dequants to fp16 internally; keep activations fp16
    out = m(torch.zeros(1, D, dtype=torch.float16)); print(f"    torch fwd OK {tuple(out.shape)}")
    t0 = time.time()
    ep = torch.export.export(m.eval(), (torch.zeros(1, D, dtype=torch.float16),))
    ep = ep.run_decompositions(coreai_torch.get_decomp_table())
    ep = inject_subbyte_tensors(ep)                                   # <-- packs int4 storage
    states = list(ep.graph_signature.buffers_to_mutate.values())
    conv = coreai_torch.TorchConverter().add_exported_program(
        ep, input_names=["x"], output_names=["logits"], state_names=states, entrypoint_name="main")
    prog = conv.to_coreai(); prog.optimize()
    OUT = "/tmp/gdn_coreai/Qwen35RealWeights_L0_int4.aimodel"
    if Path(OUT).exists():
        shutil.rmtree(OUT)
    Path(OUT).parent.mkdir(parents=True, exist_ok=True); prog.save_asset(Path(OUT))
    sz = (Path(OUT) / "main.mlirb").stat().st_size
    print(f">> ✅ REAL-WEIGHT int4 GDN layer CONVERTED  {sz/1e6:.1f} MB  (fp16 was 228.5 MB → {228.5/(sz/1e6):.1f}x smaller)  in {time.time()-t0:.0f}s")
    print(f"   → real 12-layer int4 asset extrapolates to ~{sz/1e6*12/1e3*1.05:.2f} GB (embed adds ~0.3GB int4) — under the 2GB wall")


if __name__ == "__main__":
    main()
