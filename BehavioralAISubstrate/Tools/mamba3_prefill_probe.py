"""STEP 1 of the on-device DUET probe plan (Docs/ONDEVICE_DUET_PROBE_PLAN.md): the SINGLE-LAYER prefill convertibility gate.

The #1 unproven route risk (adversarially confirmed): does the PREFILL graph CONVERT through coreai_torch at all? The decode
`step_ref` path is device-proven (addenda 7/10), but prefill is a structurally DIFFERENT graph never converted — it uses ops
decode never touches: `torch.cumsum` (RoPE angle + the scan's cumulative log-decay), `masked_fill(-inf)`+`exp` over a [T,T]
decay matrix (`scan_parallel`), big einsums, `torch.cat`; and MLA adds causal `softmax`+`triu`. Exactly the family that the
verifier flagged as the likely converter blocker.

This exports ONE Mamba `Lyr.prefill_state` and ONE MLA `MLABlock.forward_seq` (fp16, fixed T=64 hidden input) to a .aimodel.
Converter accepts the ops -> scaling to the full 24L hybrid prefill asset (STEP 3) is mechanical. Converter raises -> we learn
the exact blocking op in minutes, and the fallback is a per-token `step_ref` warm-up prefill (the device-proven decode op).
NOTE: GPU-vs-ANE placement is a LOAD-TIME Swift setting (UNITS_OVR, STEP 2 device run) — this host gate tests op-LOWERING only.

Run: cd BehavioralAISubstrate && source ~/.venvs/coreai-cv/bin/activate && python Tools/mamba3_prefill_probe.py
"""
from __future__ import annotations

import os
import shutil
import sys
from pathlib import Path

import torch
import torch.nn as nn

sys.path.insert(0, "/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tools")
import coreai_torch
from coreai_torch._compression.utils import inject_subbyte_tensors

import mamba3_mla as MLA
import mamba3_trainable as MT

T = int(os.environ.get("PROBE_T", "64"))   # PROBE_T>64 forces the chunked-scan path (scan_chunked) — the real-corpus prefill gate
D = MT.D_MODEL
OUTDIR = Path("/tmp/draft_coreai")


class LyrPrefill(nn.Module):
    def __init__(self) -> None:
        super().__init__()
        self.lyr = MT.Lyr()

    def forward(self, x_seq):                              # [T, D] -> boundary 4-state (the decode handoff)
        out_seq, (a, sm, k, v) = self.lyr.prefill_state(x_seq)
        return out_seq[-1], a, sm, k, v


class MLAPrefill(nn.Module):
    def __init__(self) -> None:
        super().__init__()
        self.blk = MLA.MLABlock()

    def forward(self, x_seq):                              # [T, D] -> (last hidden, latent KV cache [T, D_LATENT])
        out_seq, c_kv = self.blk.forward_seq(x_seq)
        return out_seq[-1], c_kv


def det_input():
    """Bit-reproducible [T,D] fp16 input (integer mod + exact fp division — IDENTICAL in Python and Swift, no libm).
    Swift mirror: xs[i] = Float16((Double(i % 97) - 48.0) / 480.0). Lets the device run feed the SAME input → numeric compare."""
    return (((torch.arange(T * D) % 97).double() - 48.0) / 480.0).to(torch.float16).view(T, D)


def stats(t):
    f = t.detach().float().reshape(-1)
    return f.pow(2).sum().sqrt().item(), f.sum().item(), [round(v, 5) for v in f[:4].tolist()]


def export_probe(model, out_names, tag):
    m = model.half().eval()
    x = det_input()
    host = m(x)                                            # host fwd must succeed (and tells us the output shapes)
    ep = torch.export.export(m, (x,))
    ep = inject_subbyte_tensors(ep.run_decompositions(coreai_torch.get_decomp_table()))
    c = coreai_torch.TorchConverter().add_exported_program(
        ep, input_names=["x_seq"], output_names=out_names, entrypoint_name="main")
    p = c.to_coreai()
    p.optimize()
    out = OUTDIR / f"Mamba3{tag}_L1_prefill.aimodel"
    if out.exists():
        shutil.rmtree(out)
    out.parent.mkdir(parents=True, exist_ok=True)
    p.save_asset(out)
    return out, host


def main() -> None:
    torch.manual_seed(0)
    print(f"STEP-1 prefill convertibility gate (T={T}, D={D}, fp16, single layer):")
    ok = 0
    probes = [
        ("MambaPrefill", LyrPrefill(), ["out_last", "angle", "ssm", "kprev", "vprev"]),
        ("MLAPrefill", MLAPrefill(), ["out_last", "c_kv"]),
    ]
    for name, model, outs in probes:
        try:
            out, host = export_probe(model, outs, name)
            print(f"  OK  {name}: CONVERTED -> {out}")
            for nm, h in zip(outs, host):                 # host REFERENCE stats — device must match these (rel-err<1e-2)
                nrm, sm, head = stats(h)
                print(f"        HOSTREF {name}.{nm} shape={tuple(h.shape)} norm={nrm:.4f} sum={sm:.4f} head={head}")
            ok += 1
        except Exception as e:
            import traceback
            tb = traceback.format_exc().strip().splitlines()
            print(f"  XX  {name}: FAILED at convert — {type(e).__name__}: {str(e)[:300]}")
            print("        " + " | ".join(tb[-3:]))
    print(f"\n{ok}/{len(probes)} prefill graphs convert. READ: 2/2 = cumsum/masked-exp-segsum/softmax-triu all lower -> STEP 2 "
          "(device GPU run + numeric compare). Any XX = that op is the prefill blocker -> fallback to per-token step_ref warm-up.")


if __name__ == "__main__":
    main()
