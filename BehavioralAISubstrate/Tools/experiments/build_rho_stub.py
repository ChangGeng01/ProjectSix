#!/usr/bin/env python3
"""Build a STUB Core AI `.aimodel` for the on-device bandwidth-contention (ρ) micro-benchmark.

This is a *bandwidth* probe, NOT a quality model — RANDOM weights are fine. The only thing that
matters is that it (a) is the right size on disk (~200-270 MB), (b) is **int8** (fp16 OOM-crashes
the A19 `aned` compiler at ~2 GB), (c) is **static-shape** (dynamic-shape exports route to GPU and
defeat the ANE bandwidth measurement), (d) has ≤8 transformer layers (the A19 per-asset ANE layer
ceiling), and (e) keeps all KV-state inner dims (head_dim, MAX_SEQ) on multiples of 32 (else the ANE
silently demotes the attention ops off-ANE).

It REUSES the proven converter infrastructure verbatim — `QuantStatefulLlamaDraft` (the stateful
Llama module with the torch.where KV-write fix, host-supplied RoPE/mask/one-hot contract, fused KV
state) and `convert_quant_to_aimodel` (torch.export → run_decompositions → inject_subbyte_tensors →
TorchConverter → to_coreai → optimize → save_asset) from `llama_to_coreai_int8.py`. The ONLY change
vs the real 1B path: a small bare config with RANDOM weights instead of an HF checkpoint load, and
the Gemma vocab (262144) so the tied embed/lm_head dominates the bytes the way it will on target.

Run:  /tmp/coreai-cv/bin/python Tools/build_rho_stub.py
Out:  /tmp/draft_coreai/rho_stub_int8.aimodel   (+ prints du -sh size + asset.summary())
"""
from __future__ import annotations

import subprocess
import sys
import warnings
from dataclasses import dataclass
from pathlib import Path

warnings.filterwarnings("ignore", category=FutureWarning)
warnings.filterwarnings("ignore", message=".*treespec.*")
warnings.filterwarnings("ignore", category=UserWarning)

import torch

# Reuse the verified quantized module + converter from the repo int8 path (no reinvention).
REPO = "/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate"
sys.path.insert(0, f"{REPO}/Tools")
from llama_to_coreai_int8 import (  # type: ignore  # noqa: E402
    QuantStatefulLlamaDraft,
    convert_quant_to_aimodel,
)
from llama_to_coreai import MAX_SEQ  # type: ignore  # noqa: E402

OUT_DIR = "/tmp/draft_coreai"
OUT = f"{OUT_DIR}/rho_stub_v32k_int8.aimodel"
NBITS = 8

# ---------------------------------------------------------------------------
# Stub config — v32k variant: a SMALL 32k vocab head (≈50 MB int8, so the ANE AOT
# specialize actually completes — the 262k Gemma head HUNG the device ANE compiler),
# with the ~200 MB bandwidth footprint moved into 6 bulked layers instead of the head.
# This SEPARATES the compile blocker (big vocab head) from the bandwidth question (ρ):
# the draft still reads ~196 MB/step so the contention measurement stays representative.
#   head_dim = hidden_size // num_attention_heads = 1536 // 24 = 64   (÷32 ✓)
#   GQA rep  = num_attention_heads // num_key_value_heads = 24 // 4 = 6   (valid)
#   KV state = [2*L, 1, n_kv, MAX_SEQ, head_dim] = [12, 1, 4, 512, 64]  (÷32 inner dims)
#   bytes ≈ head 32768×1536 int8 (50 MB) + 6 × ~24 MB layers ≈ 196 MB on disk.
# ---------------------------------------------------------------------------
@dataclass(frozen=True)
class RhoStubCfg:
    vocab_size: int = 32768            # SMALL vocab → ANE-compilable head (262k Gemma head hung the compiler)
    hidden_size: int = 1536
    num_hidden_layers: int = 6         # ≤8 A19 per-asset ANE layer ceiling; carries the bandwidth instead of the head
    num_attention_heads: int = 24      # → head_dim 64
    num_key_value_heads: int = 4       # GQA rep 6
    intermediate_size: int = 4096
    rms_norm_eps: float = 1e-5


def build_stub(cfg: RhoStubCfg) -> QuantStatefulLlamaDraft:
    """Construct the stateful Llama draft at `cfg` with RANDOM weights, then int8-quantize in place.

    `QuantStatefulLlamaDraft.__init__` (via `StatefulLlamaDraft`) takes a bare config and randomly
    initializes every weight — no HF checkpoint download is needed for a bandwidth stub.
    """
    torch.manual_seed(0)               # deterministic random weights (reproducible stub)
    draft = QuantStatefulLlamaDraft(cfg).eval()
    draft.quantize_in_place(NBITS)
    return draft


def assert_static_and_safe(cfg: RhoStubCfg) -> None:
    """Fail fast on the ANE invariants before we spend minutes converting."""
    head_dim = cfg.hidden_size // cfg.num_attention_heads
    assert cfg.hidden_size % cfg.num_attention_heads == 0, "hidden must be divisible by n_heads"
    assert head_dim == 64, f"head_dim must be 64, got {head_dim}"
    assert head_dim % 32 == 0, "head_dim must be a multiple of 32 (ANE)"
    assert MAX_SEQ % 32 == 0, "MAX_SEQ must be a multiple of 32 (ANE)"
    assert cfg.num_attention_heads % cfg.num_key_value_heads == 0, "GQA must divide evenly"
    assert cfg.num_hidden_layers <= 8, "A19 per-asset ANE layer ceiling is 8"
    print(f">> config OK: head_dim={head_dim} (÷32), MAX_SEQ={MAX_SEQ} (÷32), "
          f"GQA rep={cfg.num_attention_heads // cfg.num_key_value_heads}, "
          f"layers={cfg.num_hidden_layers}, vocab={cfg.vocab_size}")


def disk_size(path: str) -> str:
    out = subprocess.run(["du", "-sh", path], capture_output=True, text=True)
    return out.stdout.strip()


def main() -> None:
    cfg = RhoStubCfg()
    Path(OUT_DIR).mkdir(parents=True, exist_ok=True)
    assert_static_and_safe(cfg)

    print(">> building int8 stub (random weights, Gemma vocab)…")
    draft = build_stub(cfg)

    # The export uses a single fixed example arg-tuple (sample_inputs) → STATIC shapes, no
    # dynamic_shapes are passed anywhere, so every dim in the exported graph is concrete.
    print(">> converting to .aimodel (torch.export → inject_subbyte_tensors → to_coreai)…")
    convert_quant_to_aimodel(draft, OUT)

    # ---- on-disk verification ----
    print("\n================ VERIFY ================")
    print(">> du -sh:", disk_size(OUT))
    mlirb = next(Path(OUT).glob("*.mlirb"), None)
    if mlirb is not None:
        print(f">> main.mlirb = {mlirb.stat().st_size / 1e6:.1f} MB ({mlirb.stat().st_size} bytes)")
    total = sum(f.stat().st_size for f in Path(OUT).rglob("*") if f.is_file())
    mb = total / 1e6
    print(f">> total asset bytes = {total} ({mb:.1f} MB)")
    in_band = 200.0 <= mb <= 270.0
    print(f">> {'IN BAND' if in_band else 'OUT OF BAND'} (target 200-270 MB)")
    if not in_band:
        sys.exit(3)


if __name__ == "__main__":
    main()
