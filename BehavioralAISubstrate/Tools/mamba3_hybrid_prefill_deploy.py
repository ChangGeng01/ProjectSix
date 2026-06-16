"""STEP 3 of the on-device DUET probe: the FULL 24L hybrid PREFILL converter (20 Mamba-3 + 4 MLA @ L6/12/18/23) -> .aimodel.

Extends the device-proven single-layer STEP 2 (addendum 24) to the whole prefill asset. forward(x_seq [T,D]) runs all 24
layers' prefill (Mamba `prefill_state` chunked-scan + MLA `forward_seq` causal softmax) and emits the boundary handoff as
5 STACKED tensors (cleaner than 84 named outputs; stack runs on GPU, the prefill target):
  angle_all[20,H,N/2]  ssm_all[20,H,P,N]  kprev_all[20,H,R,N]  vprev_all[20,H,P,R]   (the 20 Mamba layers, in layer order)
  mla_all[4,T,D_LATENT]                                                               (the 4 MLA layers' latent KV caches)
The (separate) decode asset (STEP 4) consumes these into its initial state. Input is hidden [T,D] (skips the embedding — the
embedding is a trivial op and the real checkpoint converter re-adds it; this isolates the expensive 24-layer scan/attention).

HOST-FIDELITY GATE (R1, catches decomposition bugs like the broadcasting_mul/torch.where one): runs the EXPORTED+decomposed
graph on CPU and compares to the eager forward before saving. Then prints HOSTREF stats for the device numeric compare.

Run: cd BehavioralAISubstrate && uv run --with coreai-torch python Tools/mamba3_hybrid_prefill_deploy.py
"""
from __future__ import annotations

import os
import shutil
import sys
from pathlib import Path

import torch
import torch.nn as nn
import torch.nn.functional as F

sys.path.insert(0, "/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tools")
import coreai_torch
from coreai_torch._compression.utils import inject_subbyte_tensors

import mamba3_hybrid as HY
import mamba3_trainable as MT
from mamba3_prefill_probe import det_input, stats

T = int(os.environ.get("T", "64"))
D = MT.D_MODEL
LAYERS = int(os.environ.get("LAYERS", "24"))
VOCAB = 4096
TOKENS = os.environ.get("TOKENS") == "1"                      # TOKENS=1: input is prompt token ids [T] (embed inside) — the
#   E2E-consistent form (decode embeds the same way). Default: hidden [T,D] (isolates the 24-layer scan/attention).
OUT = Path(f"/tmp/draft_coreai/Mamba3HybridPrefill_L{LAYERS}_T{T}{'_tok' if TOKENS else ''}.aimodel")
OUT_NAMES = ["angle_all", "ssm_all", "kprev_all", "vprev_all", "mla_all"]


class DeployHybridPrefill(nn.Module):
    def __init__(self, vocab: int, layers: int) -> None:
        super().__init__()
        self.m = HY.HybridM(vocab, layers)

    def forward(self, inp):                                   # [T,D] hidden, OR [T] token ids if TOKENS -> 5 stacked states
        x = F.embedding(inp, self.m.embedding.weight) if TOKENS else inp
        ang, ssm, kp, vp, mla = [], [], [], [], []
        for i, lyr in enumerate(self.m.layers):
            if self.m._is_mla(i):
                x, c = lyr.forward_seq(x)
                mla.append(c)
            else:
                x, (a, sm, k, v) = lyr.prefill_state(x)
                ang.append(a); ssm.append(sm); kp.append(k); vp.append(v)
        return torch.stack(ang), torch.stack(ssm), torch.stack(kp), torch.stack(vp), torch.stack(mla)


def det_tokens(n, vocab=VOCAB):
    """Deterministic token ids — mirrored in Swift (tok[i] = (i*17+5) % vocab) for the E2E."""
    return torch.tensor([(i * 17 + 5) % vocab for i in range(n)], dtype=torch.long)


def main() -> None:
    torch.manual_seed(0)
    vocab, sd = HY.resolve_ckpt(VOCAB, LAYERS)                # CKPT env → trained weights + Granite vocab; else random/4096
    m = DeployHybridPrefill(vocab, LAYERS)
    if sd is not None:
        miss, unexp = m.m.load_state_dict(sd, strict=False)
        assert not unexp, f"CKPT has keys DeployHybridPrefill.m lacks: {unexp[:3]}"
        assert not miss, f"CKPT did NOT supply trained params (would deploy random init): {miss[:5]}"
        print(f"loaded TRAINED ckpt (vocab={vocab}; all {len(sd)} trained tensors consumed)")
    m = m.half().eval()
    x = det_tokens(T, vocab) if TOKENS else det_input(T)
    in_name = "input_ids" if TOKENS else "x_seq"
    print(f"STEP-3 full {LAYERS}L hybrid prefill converter (T={T}, D={D}, fp16, input={'tokens' if TOKENS else 'hidden'}, {len(m.m.mla_pos)} MLA @ {sorted(m.m.mla_pos)}):")

    eager = m(x)
    ep = torch.export.export(m, (x,))
    ep = inject_subbyte_tensors(ep.run_decompositions(coreai_torch.get_decomp_table()))
    decomp = ep.module()(x)                                   # run the EXPORTED+decomposed graph on CPU (fidelity gate)
    worst = max((e.float() - d.float()).abs().max().item() / max(e.float().abs().max().item(), 1e-6)
                for e, d in zip(eager, decomp))
    print(f"  host-fidelity (eager vs exported-decomposed): worst rel max-err {worst:.2e} -> {'PASS' if worst < 1e-2 else 'FAIL'}")

    c = coreai_torch.TorchConverter().add_exported_program(
        ep, input_names=[in_name], output_names=OUT_NAMES, entrypoint_name="main")
    p = c.to_coreai(); p.optimize()
    if OUT.exists():
        shutil.rmtree(OUT)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    p.save_asset(OUT)
    sz = sum(f.stat().st_size for f in OUT.rglob("*") if f.is_file()) / 1e6
    print(f"  CONVERTED -> {OUT}  ({sz:.0f} MB)")
    for nm, h in zip(OUT_NAMES, eager):
        nrm, sm, head = stats(h)
        print(f"        HOSTREF Hybrid.{nm} shape={tuple(h.shape)} norm={nrm:.4f} sum={sm:.4f} head={head}")
    print("\nREAD: host-fidelity PASS + CONVERTED = the full 24L prefill asset is built. Stage + run on device (STEP-3 latency) "
          "via BAS_COREAI_PREFILL_PROBE with the Hybrid entry; device norms must match these HOSTREF lines.")


if __name__ == "__main__":
    main()
