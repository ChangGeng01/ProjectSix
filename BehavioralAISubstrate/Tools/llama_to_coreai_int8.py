#!/usr/bin/env python3
"""int8 / int4 weight-quantized stateful Llama-3.2-1B → Apple Core AI `.aimodel`.

Sibling of `Tools/llama_to_coreai.py`. SAME StatefulLlamaDraft module + SAME host-supplied
RoPE/mask/one-hot I/O contract + SAME per-layer fused KV state. Only difference: every weight
matrix (q/k/v/o/gate/up/down Linears + the tied embed/lm_head) is stored as a per-output-channel
**int8 (or int4)** tensor + an fp16 scale, and dequantized inside `forward` via the lowered
`coreai::constexpr_blockwise_shift_scale` custom op. RMSNorm gammas / RoPE / activations stay fp16.

Why: the fp16 1B `.aimodel` main.mlirb is 2.3 GB; the A19 `aned` compiler OOM-crashes compiling it.
int8 halves the weight bytes (~1.2 GB main.mlirb), int4 quarters them (~0.66 GB) so it fits.

THE QUANTIZATION IDIOM (coreai_torch 0.4.0, discovered by reading _compression/):
  1. Per-output-channel symmetric quant:  q = round(w / scale) clamped to [-2^(b-1), 2^(b-1)-1],
     scale = max(|w|, axis=1) / (2^(b-1)-1)   (shape [out,1], fp16).  q stored as **int8** (int4
     values live inside an int8 container until export-time packing).
  2. Replace each nn.Linear with a `QuantLinear` whose forward calls
        torch.ops.coreai.constexpr_blockwise_shift_scale(q_int8, scale_fp16, output_dtype=fp16)
     → fp16 weight, then F.linear.  This puts the int8 constant + a dequant directly in the graph.
  3. torch.export → run_decompositions(get_decomp_table())  (coreai:: custom ops survive — they're
     never in the decomp table).
  4. **inject_subbyte_tensors(ep)** — promotes the int8 constants to packed int4 storage when the
     blockwise-shift-scale op's input_dtype says 4 bits (no-op for int8).  THIS is what makes int4
     actually quarter the bytes on disk instead of staying int8.
  5. TorchConverter().add_exported_program(...).to_coreai().optimize().save_asset().

Run:  /tmp/coreai-cv/bin/python /tmp/llama_to_coreai_int8.py [8|4|both]
Out:  /tmp/draft_coreai/LlamaDraft1B_int8.aimodel  /  LlamaDraft1B_int4.aimodel
"""
from __future__ import annotations

import asyncio
import inspect
import sys
import warnings
from pathlib import Path

warnings.filterwarnings("ignore", category=FutureWarning)
warnings.filterwarnings("ignore", message=".*treespec.*")
warnings.filterwarnings("ignore", category=UserWarning)

import numpy as np
import torch
import torch.nn as nn
import torch.nn.functional as F
import coreai_torch
from coreai.runtime import AIModel, NDArray
from coreai_torch._compression.custom_layers import constexpr_blockwise_shift_scale  # noqa: F401  (registers op)
from coreai_torch._compression.utils import inject_subbyte_tensors

# Reuse the verified module + weight-copy + sample-inputs from the repo converter.
sys.path.insert(0, str(Path(__file__).resolve().parent))
REPO = "/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate"
sys.path.insert(0, f"{REPO}/Tools")
from llama_to_coreai import (  # type: ignore  # noqa: E402
    StatefulLlamaDraft,
    copy_weights,
    sample_inputs,
    rotate_half,
    MAX_SEQ,
)

MODEL = "unsloth/Llama-3.2-1B-Instruct"
REVISION = "5a8abab4a5d6f164389b1079fb721cfab8d7126c"
OUT_DIR = "/tmp/draft_coreai"


# ---------------------------------------------------------------------------
# Weight-only per-output-channel symmetric int-N quantization
# ---------------------------------------------------------------------------
def quantize_per_ochannel(weight: torch.Tensor, nbits: int) -> tuple[torch.Tensor, torch.Tensor]:
    """Symmetric per-output-channel (axis 0) quant of a [out,in] weight.

    Returns (q_int8, scale_fp16[out,1]).  q holds values in the int-N range but is stored as int8
    (the container PyTorch's export path understands; inject_subbyte_tensors packs int4 later).
    """
    qmax = (1 << (nbits - 1)) - 1            # 127 for int8, 7 for int4
    qmin = -(1 << (nbits - 1))               # -128 for int8, -8 for int4
    w = weight.detach().to(torch.float32)
    amax = w.abs().amax(dim=1, keepdim=True)            # [out,1]
    scale = (amax / qmax).clamp(min=1e-12)              # avoid /0 for all-zero rows
    q = torch.round(w / scale).clamp(qmin, qmax).to(torch.int8)
    return q, scale.to(torch.float16)


class QuantLinear(nn.Module):
    """Drop-in for a bias-free nn.Linear with an int8/int4-stored weight.

    forward:  w = coreai::constexpr_blockwise_shift_scale(q_int8, scale, input_dtype, output_dtype=fp16)
              y = x @ w.T
    The op carries the int8 constant in the exported graph; CoreAI lowers it to int storage.
    """

    def __init__(self, weight: torch.Tensor, nbits: int) -> None:
        super().__init__()
        q, scale = quantize_per_ochannel(weight, nbits)
        self.register_buffer("quantized_data", q)          # int8 [out,in]
        self.register_buffer("scale", scale)               # fp16 [out,1]  (per-output-channel)
        # input_dtype tells the converter the LOGICAL sub-byte width (int4 lives in an int8 box).
        self.input_dtype = torch.int4 if nbits == 4 else torch.int8

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        w = torch.ops.coreai.constexpr_blockwise_shift_scale(
            self.quantized_data, self.scale, input_dtype=self.input_dtype, output_dtype=torch.float16,
        )
        return F.linear(x, w.to(x.dtype))


class QuantEmbed(nn.Module):
    """Tied embed + lm_head with an int8/int4-stored table [vocab, hidden].

    Reconstructs the fp16 table once via the coreai dequant op, then uses it for BOTH the lookup
    (embedding) and the tied lm_head matmul — exactly mirroring the fp16 module's use of embed.weight.
    """

    def __init__(self, weight: torch.Tensor, nbits: int) -> None:
        super().__init__()
        q, scale = quantize_per_ochannel(weight, nbits)    # per-row (per token-id) scale
        self.register_buffer("quantized_data", q)
        self.register_buffer("scale", scale)
        self.input_dtype = torch.int4 if nbits == 4 else torch.int8

    def weight_fp16(self) -> torch.Tensor:
        return torch.ops.coreai.constexpr_blockwise_shift_scale(
            self.quantized_data, self.scale, input_dtype=self.input_dtype, output_dtype=torch.float16,
        )

    def forward(self, ids: torch.Tensor) -> torch.Tensor:
        return F.embedding(ids, self.weight_fp16())


class QuantStatefulLlamaDraft(StatefulLlamaDraft):
    """StatefulLlamaDraft with every weight matrix int-quantized. forward is overridden so the tied
    lm_head reads the dequantized embed table (the base class did `x @ self.embed.weight.t()`)."""

    def quantize_in_place(self, nbits: int) -> "QuantStatefulLlamaDraft":
        for li in range(self.n_layers):
            for proj in (self.q, self.k, self.v, self.o, self.gate, self.up, self.down):
                proj[li] = QuantLinear(proj[li].weight, nbits)
        self.embed = QuantEmbed(self.embed.weight, nbits)
        return self

    def forward(self, input_id, rope_cos, rope_sin, write_onehot, attn_bias):
        oh = write_onehot.view(1, 1, MAX_SEQ, 1)
        write_mask = (oh > 0.5).expand(1, self.n_kv, MAX_SEQ, self.head_dim)
        bias = attn_bias.view(1, 1, 1, MAX_SEQ)
        cos = rope_cos.view(1, 1, 1, self.head_dim)
        sin = rope_sin.view(1, 1, 1, self.head_dim)
        embed_w = self.embed.weight_fp16()          # dequant once, reuse for lookup + lm_head
        x = F.embedding(input_id, embed_w)
        kv = self.kv
        new_slots = []
        for li in range(self.n_layers):
            h = self._rms(x, self.in_norm[li])
            q = self.q[li](h).view(1, 1, self.n_heads, self.head_dim).transpose(1, 2)
            k = self.k[li](h).view(1, 1, self.n_kv, self.head_dim).transpose(1, 2)
            v = self.v[li](h).view(1, 1, self.n_kv, self.head_dim).transpose(1, 2)
            half = self.head_dim // 2
            q = q * cos + rotate_half(q, half) * sin
            k = k * cos + rotate_half(k, half) * sin
            kc = torch.where(write_mask, k.expand(1, self.n_kv, MAX_SEQ, self.head_dim), kv[2 * li])
            vc = torch.where(write_mask, v.expand(1, self.n_kv, MAX_SEQ, self.head_dim), kv[2 * li + 1])
            new_slots.append(kc)
            new_slots.append(vc)
            kr = kc.repeat_interleave(self.rep, dim=1)
            vr = vc.repeat_interleave(self.rep, dim=1)
            scores = (q @ kr.transpose(-1, -2)) * self.scale + bias
            attn = torch.softmax(scores, dim=-1)
            out = (attn @ vr).transpose(1, 2).reshape(1, 1, self.n_heads * self.head_dim)
            x = x + self.o[li](out)
            h2 = self._rms(x, self.post_norm[li])
            x = x + self.down[li](F.silu(self.gate[li](h2)) * self.up[li](h2))
        self.kv[:, :, :, :, :] = torch.stack(new_slots, dim=0)
        x = self._rms(x, self.final_norm)
        return x @ embed_w.to(x.dtype).t()


# ---------------------------------------------------------------------------
# Convert (with the subbyte-injection pass)
# ---------------------------------------------------------------------------
def convert_quant_to_aimodel(draft: QuantStatefulLlamaDraft, out_path: str) -> object:
    # fp16 graph: float inputs must be fp16 so dtypes line up with the dequantized weights.
    ep = torch.export.export(draft.eval(), sample_inputs(draft.head_dim, torch.float16))
    ep = ep.run_decompositions(coreai_torch.get_decomp_table())
    # THE int4 packing pass — promote int8-boxed sub-byte constants to packed int4 storage.
    ep = inject_subbyte_tensors(ep)
    state_names = list(ep.graph_signature.buffers_to_mutate.values())
    print(f">> {len(state_names)} state tensors: {state_names[:2]}…")
    conv = coreai_torch.TorchConverter().add_exported_program(
        ep,
        input_names=["input_id", "rope_cos", "rope_sin", "write_onehot", "attn_bias"],
        output_names=["logits"],
        state_names=state_names,
        entrypoint_name="main",
    )
    prog = conv.to_coreai()
    prog.optimize()
    if Path(out_path).exists():
        import shutil
        shutil.rmtree(out_path)
    asset = prog.save_asset(Path(out_path))
    print(f">> SAVED {out_path}")
    try:
        summary = asset.summary()
        print(">> asset summary:", summary)
    except Exception as e:  # noqa: BLE001
        print(">> summary n/a:", e)
    return asset


async def _aw(x):
    return await x if inspect.isawaitable(x) else x


def main() -> None:
    which = sys.argv[1] if len(sys.argv) > 1 else "both"
    nbits_list = {"8": [8], "4": [4], "both": [8, 4]}[which]
    Path(OUT_DIR).mkdir(parents=True, exist_ok=True)

    from transformers import AutoModelForCausalLM, AutoTokenizer
    print(f">> loading {MODEL} (revision={REVISION})")
    hf = AutoModelForCausalLM.from_pretrained(MODEL, revision=REVISION, dtype=torch.float32).eval()
    tok = AutoTokenizer.from_pretrained(MODEL, revision=REVISION)
    cfg = hf.config
    rotary = hf.model.rotary_emb

    def cos_sin(pos: int):
        pid = torch.tensor([[pos]], dtype=torch.long)
        dummy = torch.zeros(1, 1, cfg.hidden_size)
        cos, sin = rotary(dummy, pid)
        return cos[0, 0], sin[0, 0]

    # HF greedy reference
    prompt = "The capital of France is"
    ids = tok(prompt, return_tensors="pt").input_ids
    n_new = 24
    with torch.no_grad():
        hf_out = hf.generate(ids, max_new_tokens=n_new, do_sample=False, use_cache=True,
                             pad_token_id=tok.eos_token_id)
    hf_new = hf_out[0, ids.shape[1]:].tolist()
    print(f">> HF greedy ref: {tok.decode(hf_new)!r}")

    results = []
    for nbits in nbits_list:
        tag = f"int{nbits}"
        out = f"{OUT_DIR}/LlamaDraft1B_{tag}.aimodel"
        print(f"\n================ {tag} ================")
        draft = QuantStatefulLlamaDraft(cfg).eval()
        copy_weights(draft, hf)
        draft.quantize_in_place(nbits)

        # ---- TORCH fidelity of the quantized module (sanity before convert) ----
        def step(tid: int, pos: int):
            c, s = cos_sin(pos)
            c, s = c.to(torch.float16), s.to(torch.float16)
            oh = torch.zeros(MAX_SEQ, dtype=torch.float16); oh[pos] = 1.0
            bias = torch.zeros(MAX_SEQ, dtype=torch.float16); bias[pos + 1:] = -1e4
            with torch.no_grad():
                lg = draft(torch.tensor([[tid]], dtype=torch.long), c, s, oh, bias)
            return lg[0, 0].float()
        pos = 0
        for t in ids[0].tolist():
            logits = step(t, pos); pos += 1
        tnew = []
        nxt = int(logits.argmax())
        for _ in range(n_new):
            tnew.append(nxt); logits = step(nxt, pos); pos += 1; nxt = int(logits.argmax())
        tmatch = sum(1 for a, b in zip(hf_new, tnew) if a == b)
        print(f">> TORCH({tag}) token_match={tmatch}/{n_new}  text={tok.decode(tnew)!r}")

        convert_quant_to_aimodel(draft, out)

        # ---- main.mlirb size ----
        mlirb = next(Path(out).glob("*.mlirb"))
        size_b = mlirb.stat().st_size
        print(f">> {tag} main.mlirb = {size_b/1e9:.3f} GB ({size_b} bytes)")

        # ---- AIMODEL host fidelity (the shipped artifact, via coreai.runtime) ----
        async def cm_fidelity(path=out):
            model = await _aw(AIModel.load(path))
            fn = await _aw(model.load_function("main"))
            st = {"kv": NDArray(np.zeros((2 * draft.n_layers, 1, draft.n_kv, MAX_SEQ, draft.head_dim), np.float32))}

            async def cm_step(tid: int, p: int):
                # fp16 graph: ALL float inputs must be float16 (rope_cos/sin/onehot/bias).
                c, s = cos_sin(p)
                oh = np.zeros(MAX_SEQ, np.float16); oh[p] = 1.0
                bias = np.zeros(MAX_SEQ, np.float16); bias[p + 1:] = -1e4
                o = await _aw(fn(inputs={
                    "input_id": NDArray(np.array([[tid]], np.int32)),
                    "rope_cos": NDArray(c.numpy().astype(np.float16)),
                    "rope_sin": NDArray(s.numpy().astype(np.float16)),
                    "write_onehot": NDArray(oh), "attn_bias": NDArray(bias),
                }, state=st))
                return np.asarray(o["logits"].numpy()).reshape(-1)

            p = 0
            for t in ids[0].tolist():
                lg = await cm_step(t, p); p += 1
            cm_new = []
            nxt = int(lg.argmax())
            for _ in range(n_new):
                cm_new.append(nxt); lg = await cm_step(nxt, p); p += 1; nxt = int(lg.argmax())
            return cm_new

        try:
            cm_new = asyncio.run(cm_fidelity())
            cm_match = sum(1 for a, b in zip(hf_new, cm_new) if a == b)
            print(f">> AIMODEL({tag}) token_match={cm_match}/{n_new}  text={tok.decode(cm_new)!r}")
        except Exception as e:  # noqa: BLE001
            cm_match = -1
            print(f">> AIMODEL({tag}) host run FAILED: {e}")

        results.append((tag, size_b, tmatch, cm_match))

    print("\n================ SUMMARY ================")
    print(f"fp16 baseline main.mlirb = 2.300 GB (2471833840 bytes)")
    for tag, size_b, tmatch, cm_match in results:
        print(f"{tag}: main.mlirb={size_b/1e9:.3f} GB | torch_match={tmatch}/24 | aimodel_match={cm_match}/24")


if __name__ == "__main__":
    main()
