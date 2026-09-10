#!/usr/bin/env python3
"""M3-HOST: run the FIXED 3-asset chain (int8 + full-causal) on the REAL CoreAI host runtime, verify vs MLX.

The audit's biggest open item: torch RECIPE fidelity was verified (cos 0.9999), but the CONVERTED .aimodel runtime
fidelity was not. This runs the actual converted assets through coreai.runtime (the same host runtime that certified
Llamba 24/24): chain asset1(L0-11) → asset2(L12-23) → asset3(L24-31+head) with host-side embed lookup, feed the
T=32 golden token sequence, compare final logits vs the MLX golden + report per-asset state handling.
"""
from __future__ import annotations
import asyncio, glob, inspect, sys
import numpy as np
sys.path.insert(0, str(__import__("pathlib").Path(__file__).parent))  # co-located Tools/ deps

GV, GHD, MAXSEQ, AKV, AHD, D = 32, 128, 64, 4, 256, 2560
def is_lin(i): return (i + 1) % 4 != 0


def state_spec(a, b):
    """Reconstruct the state names+shapes exactly as the Asset class registered them."""
    spec = {}
    for j, i in enumerate(range(a, b)):
        if is_lin(i):
            spec[f"gs{j}"] = (GV, GHD, GHD); spec[f"gc{j}"] = (3, 8192)
        else:
            spec[f"fk{j}"] = (MAXSEQ, AKV, AHD); spec[f"fv{j}"] = (MAXSEQ, AKV, AHD)
    spec["pos"] = (1,)
    return spec


async def _aw(x):
    return await x if inspect.isawaitable(x) else x


async def run():
    from coreai.runtime import AIModel, NDArray
    from qwen35_realweights_to_coreai import load_st, dequant
    print(">> host-side embed (dequant, fp16)...")
    st_w = load_st()
    embed = dequant(st_w, "language_model.model.embed_tokens").numpy()   # [vocab, D] fp16

    assets, states = [], []
    for name, a, b in [("Qwen35fix_asset1_L0-11_int8", 0, 12),
                       ("Qwen35fix_asset2_L12-23_int8", 12, 24),
                       ("Qwen35fix_asset3_L24-31_head_int8", 24, 32)]:
        path = f"/tmp/gdn_coreai/{name}.aimodel"
        print(f">> loading {name} ...")
        m = await _aw(AIModel.load(path))
        fn = await _aw(m.load_function("main"))
        st = {nm: NDArray(np.zeros(shape, np.float16)) for nm, shape in state_spec(a, b).items()}
        assets.append(fn); states.append(st)
    print(">> all 3 assets loaded on the CoreAI host runtime")

    toks = np.load("/tmp/gdn_coreai/mlx_toks32.npy"); T = len(toks)
    last = None
    for t in range(T):
        h = embed[int(toks[t])].reshape(1, D)                            # host embed lookup
        for k in range(3):
            res = await _aw(assets[k](inputs={"x": NDArray(h.astype(np.float16))}, state=states[k]))
            h = np.asarray(res["out"].numpy()).reshape(1, -1)
        last = h.reshape(-1)                                             # asset3 out = logits [vocab]
        if t % 8 == 7:
            print(f"   t={t+1}/{T} ok (logits dim {last.shape[0]})")

    mlx = np.load("/tmp/gdn_coreai/mlx_logits32.npy")
    lastf = last.astype(np.float32)
    cos = float(np.dot(lastf, mlx) / (np.linalg.norm(lastf) * np.linalg.norm(mlx)))
    my5 = lastf.argsort()[-5:][::-1].tolist(); mx5 = mlx.argsort()[-5:][::-1].tolist()
    ov = len(set(my5) & set(mx5))
    print(f">> M3-HOST: CoreAI-runtime 3-asset chain vs MLX (T={T}): cos={cos:.4f} top5-ov={ov}/5")
    print(f"   host top5={my5}  mlx top5={mx5}")
    print(">> " + ("✅ M3-HOST PASS — converted assets are RUNTIME-faithful" if cos > 0.995 and ov >= 4
                   else "⚠️ M3-HOST FAIL — conversion/runtime diverges from the verified torch recipe"))


if __name__ == "__main__":
    asyncio.run(run())
