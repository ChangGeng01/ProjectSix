#!/usr/bin/env python3
"""Build a Llama-3.2-1B-SHAPED stateful Core AI `.aimodel` (int8) for the CoreAI-GPU kernel probe.

This is a *kernel-speed* asset, NOT a quality model — RANDOM weights are fine: on-device decode
tok/s depends only on the matmul SHAPES (layer count, hidden, heads, vocab), never on weight values.
So a correctly-SHAPED Llama-1B random-weight int8 asset measures CoreAI-GPU's real 1B decode speed,
while AVOIDING every fidelity gotcha (broadcasting_mul etc. affect output correctness, not speed).

vs build_rho_stub.py: SAME converter infra (QuantStatefulLlamaDraft + convert_quant_to_aimodel from
llama_to_coreai_int8.py), but REAL Llama-3.2-1B dims and the ≤8-layer ANE assert RELAXED (this asset
targets `.gpu`, which has no per-asset layer ceiling — that was an ANE constraint). int8 keeps it
~1.2 GB, under the ~2 GB CoreAI single-asset wall (fp16 2.3 GB SIGABRTs on .gpu load).

Run:  /tmp/coreai-cv/bin/python Tools/build_llama1b_coreai.py
Out:  /tmp/draft_coreai/llama1b_v128k_int8.aimodel
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

REPO = "/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate"
sys.path.insert(0, f"{REPO}/Tools")
from llama_to_coreai_int8 import (  # type: ignore  # noqa: E402
    QuantStatefulLlamaDraft,
    convert_quant_to_aimodel,
)
from llama_to_coreai import MAX_SEQ  # type: ignore  # noqa: E402

OUT_DIR = "/tmp/draft_coreai"
OUT = f"{OUT_DIR}/llama1b_v128k_int8.aimodel"
NBITS = 8


# Real Llama-3.2-1B-Instruct dims (config.json): the asset must match what BASCoreAIDecodeSession
# passes (nLayers=16, nKV=8, headDim=64) so the fused KV state [2*16,1,8,MAX_SEQ,64] lines up.
#   head_dim = hidden_size // num_attention_heads = 2048 // 32 = 64   (÷32 ✓)
#   GQA rep  = num_attention_heads // num_key_value_heads = 32 // 8 = 4   (valid)
#   int8 bytes ≈ (vocab 128256×2048 tied head ≈ 263M) + 16 layers × ~50M ≈ ~1.05-1.2 GB on disk.
@dataclass(frozen=True)
class Llama1BCfg:
    vocab_size: int = 128256
    hidden_size: int = 2048
    num_hidden_layers: int = 16
    num_attention_heads: int = 32     # → head_dim 64
    num_key_value_heads: int = 8      # GQA rep 4
    intermediate_size: int = 8192
    rms_norm_eps: float = 1e-5


def build(cfg: Llama1BCfg) -> QuantStatefulLlamaDraft:
    torch.manual_seed(0)               # deterministic random weights (reproducible asset)
    draft = QuantStatefulLlamaDraft(cfg).eval()
    draft.quantize_in_place(NBITS)
    return draft


def assert_safe(cfg: Llama1BCfg) -> None:
    head_dim = cfg.hidden_size // cfg.num_attention_heads
    assert cfg.hidden_size % cfg.num_attention_heads == 0, "hidden must divide n_heads"
    assert head_dim == 64, f"head_dim must be 64, got {head_dim}"
    assert head_dim % 32 == 0, "head_dim must be ÷32 (ANE/Metal alignment)"
    assert MAX_SEQ % 32 == 0, "MAX_SEQ must be ÷32"
    assert cfg.num_attention_heads % cfg.num_key_value_heads == 0, "GQA must divide evenly"
    # NOTE: NO ≤8-layer assert — this asset targets .gpu (no per-asset layer ceiling; that's ANE-only).
    print(f">> config OK: head_dim={head_dim} (÷32), MAX_SEQ={MAX_SEQ} (÷32), "
          f"GQA rep={cfg.num_attention_heads // cfg.num_key_value_heads}, "
          f"layers={cfg.num_hidden_layers}, vocab={cfg.vocab_size}")


def disk_size(path: str) -> str:
    out = subprocess.run(["du", "-sh", path], capture_output=True, text=True)
    return out.stdout.strip()


def main() -> None:
    cfg = Llama1BCfg()
    Path(OUT_DIR).mkdir(parents=True, exist_ok=True)
    assert_safe(cfg)
    print(">> building int8 Llama-1B-shaped stub (random weights)…")
    draft = build(cfg)
    print(">> converting to .aimodel (torch.export → inject_subbyte_tensors → to_coreai)…")
    convert_quant_to_aimodel(draft, OUT)
    print("\n================ VERIFY ================")
    print(">> du -sh:", disk_size(OUT))
    total = sum(f.stat().st_size for f in Path(OUT).rglob("*") if f.is_file())
    mb = total / 1e6
    print(f">> total asset bytes = {total} ({mb:.1f} MB)")
    # Sanity: a 1B int8 asset should be ~900-1400 MB. Out of band = a config/quant problem.
    print(f">> {'IN BAND' if 800.0 <= mb <= 1500.0 else 'OUT OF BAND (expected ~900-1400 MB)'}")


if __name__ == "__main__":
    main()
