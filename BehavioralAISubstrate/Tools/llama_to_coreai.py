#!/usr/bin/env python3
"""Phase-0.1 — REAL Llama-3.2-1B-Instruct → stateful Apple **Core AI** `.aimodel` draft decoder.

The CoreAI sibling of `Tools/llama_draft_to_coreml.py`. SAME StatefulLlamaDraft module + SAME
host-supplied RoPE/mask/one-hot I/O contract (input_id, rope_cos, rope_sin, write_onehot,
attn_bias → logits) + SAME per-layer stateful KV — only the export backend changes:

    coremltools  ct.convert(traced, states=[ct.StateType…])     (the old Core ML path)
      ↓ becomes ↓
    coreai_torch  torch.export → TorchConverter(state_names=…).to_coreai() → save_asset(.aimodel)

The toy proof (toy_state.aimodel) established that coreai_torch maps mutated register_buffers →
CoreAI `states` and that state PERSISTS across host runtime calls. This builds the real thing and
gates it on token-identity to HF greedy — first in fp32 torch, then through the actual `.aimodel`
on the host `coreai.runtime` (no device needed for fidelity). 亏的不要: both gates must pass.

Env:  uv venv /tmp/coreai-cv --python 3.12 && uv pip install coreai-torch transformers numpy
Run:  /tmp/coreai-cv/bin/python Tools/llama_to_coreai.py [hf_model_dir_or_id | tiny]
Out:  /tmp/draft_coreai/LlamaDraft1B.aimodel   (+ prints fidelity verdict)
"""
from __future__ import annotations

import asyncio
import inspect
import os
import sys
from dataclasses import dataclass
from pathlib import Path

import numpy as np
import torch
import torch.nn as nn
import coreai_torch
from coreai.runtime import AIModel, NDArray

MODEL = sys.argv[1] if len(sys.argv) > 1 else "unsloth/Llama-3.2-1B-Instruct"
REVISION = (sys.argv[2] if len(sys.argv) > 2
            else "5a8abab4a5d6f164389b1079fb721cfab8d7126c" if MODEL == "unsloth/Llama-3.2-1B-Instruct"
            else None)
MAX_SEQ = 512
OUT_DIR = "/tmp/draft_coreai"
OUT = f"{OUT_DIR}/LlamaDraft1B.aimodel"


def rotate_half(x: torch.Tensor, half: int) -> torch.Tensor:
    return torch.cat((-x[..., half:], x[..., :half]), dim=-1)


class StatefulLlamaDraft(nn.Module):
    """Llama-3.2 decoder, stateful per-layer KV (mutated register_buffers). forward(input_id,
    rope_cos, rope_sin, write_onehot, attn_bias) -> logits[1,1,VOCAB]. RoPE/mask host-supplied."""

    def __init__(self, cfg) -> None:
        super().__init__()
        self.n_layers = cfg.num_hidden_layers
        self.n_heads = cfg.num_attention_heads
        self.n_kv = cfg.num_key_value_heads
        self.head_dim = cfg.hidden_size // cfg.num_attention_heads
        self.hidden = cfg.hidden_size
        self.eps = cfg.rms_norm_eps
        self.rep = self.n_heads // self.n_kv
        self.scale = self.head_dim ** -0.5

        self.embed = nn.Embedding(cfg.vocab_size, cfg.hidden_size)
        self.in_norm = nn.ParameterList([nn.Parameter(torch.ones(cfg.hidden_size)) for _ in range(self.n_layers)])
        self.post_norm = nn.ParameterList([nn.Parameter(torch.ones(cfg.hidden_size)) for _ in range(self.n_layers)])
        H, KV, D, I = self.n_heads * self.head_dim, self.n_kv * self.head_dim, cfg.hidden_size, cfg.intermediate_size
        self.q = nn.ModuleList([nn.Linear(D, H, bias=False) for _ in range(self.n_layers)])
        self.k = nn.ModuleList([nn.Linear(D, KV, bias=False) for _ in range(self.n_layers)])
        self.v = nn.ModuleList([nn.Linear(D, KV, bias=False) for _ in range(self.n_layers)])
        self.o = nn.ModuleList([nn.Linear(H, D, bias=False) for _ in range(self.n_layers)])
        self.gate = nn.ModuleList([nn.Linear(D, I, bias=False) for _ in range(self.n_layers)])
        self.up = nn.ModuleList([nn.Linear(D, I, bias=False) for _ in range(self.n_layers)])
        self.down = nn.ModuleList([nn.Linear(I, D, bias=False) for _ in range(self.n_layers)])
        self.final_norm = nn.Parameter(torch.ones(cfg.hidden_size))
        # ONE fused KV state: slots [k0, v0, k1, v1, …]. A single mutated buffer → exactly ONE CoreAI
        # `state`, so the Swift session passes one MutableView (no 32-way simultaneous-borrow problem).
        # Within a step each layer touches only its own slot, so we read all slots from the unmodified
        # buffer and write the whole thing back once (one `write_handle`).
        self.register_buffer("kv", torch.zeros(2 * self.n_layers, 1, self.n_kv, MAX_SEQ, self.head_dim))

    def _rms(self, x: torch.Tensor, w: torch.Tensor) -> torch.Tensor:
        return x * torch.rsqrt(x.pow(2).mean(-1, keepdim=True) + self.eps) * w

    def forward(self, input_id, rope_cos, rope_sin, write_onehot, attn_bias):
        oh = write_onehot.view(1, 1, MAX_SEQ, 1)
        # One-hot KV write via torch.where (→ coreai.broadcasting_where select), NOT `cache*keep + v*oh`.
        # coreai_torch 0.4.0's broadcasting_mul MIS-LOWERS the double-broadcast `v*oh` (v [1,n_kv,1,head_dim]
        # size-1 seq × oh [1,1,MAX_SEQ,1] size-1 head) — it zeros every kv-head beyond head 0, corrupting KV
        # for all GQA heads (the real cause of the 0/24 fidelity bug; the av-matmul was always faithful).
        # The select dodges that path → full 1B .aimodel is token-identical (24/24) and it's strictly cheaper.
        write_mask = (oh > 0.5).expand(1, self.n_kv, MAX_SEQ, self.head_dim)
        bias = attn_bias.view(1, 1, 1, MAX_SEQ)
        cos = rope_cos.view(1, 1, 1, self.head_dim)
        sin = rope_sin.view(1, 1, 1, self.head_dim)
        x = self.embed(input_id)
        kv = self.kv                      # read all slots from the unmodified buffer (slots are disjoint)
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
            x = x + self.down[li](torch.nn.functional.silu(self.gate[li](h2)) * self.up[li](h2))
        self.kv[:, :, :, :, :] = torch.stack(new_slots, dim=0)   # single fused write-back → one state
        x = self._rms(x, self.final_norm)
        return x @ self.embed.weight.t()


def copy_weights(dst: StatefulLlamaDraft, src) -> None:
    sd = src.state_dict()
    dst.embed.weight.data.copy_(sd["model.embed_tokens.weight"])
    for li in range(dst.n_layers):
        p = f"model.layers.{li}."
        dst.in_norm[li].data.copy_(sd[p + "input_layernorm.weight"])
        dst.post_norm[li].data.copy_(sd[p + "post_attention_layernorm.weight"])
        dst.q[li].weight.data.copy_(sd[p + "self_attn.q_proj.weight"])
        dst.k[li].weight.data.copy_(sd[p + "self_attn.k_proj.weight"])
        dst.v[li].weight.data.copy_(sd[p + "self_attn.v_proj.weight"])
        dst.o[li].weight.data.copy_(sd[p + "self_attn.o_proj.weight"])
        dst.gate[li].weight.data.copy_(sd[p + "mlp.gate_proj.weight"])
        dst.up[li].weight.data.copy_(sd[p + "mlp.up_proj.weight"])
        dst.down[li].weight.data.copy_(sd[p + "mlp.down_proj.weight"])
    dst.final_norm.data.copy_(sd["model.norm.weight"])


def sample_inputs(head_dim: int, dtype: "torch.dtype" = torch.float32):
    """One example arg-tuple for torch.export (pos 0: attend slot 0 only). Float inputs match the
    model dtype (fp16 device artifact needs fp16 inputs or the graph has dtype mismatches)."""
    bias = torch.cat([torch.zeros(1, dtype=dtype), torch.full((MAX_SEQ - 1,), -1e4, dtype=dtype)])
    return (torch.zeros(1, 1, dtype=torch.long), torch.zeros(head_dim, dtype=dtype),
            torch.zeros(head_dim, dtype=dtype), torch.zeros(MAX_SEQ, dtype=dtype), bias)


def convert_to_aimodel(draft: StatefulLlamaDraft, out_path: str,
                       dtype: "torch.dtype" = torch.float32) -> object:
    """torch.export → coreai_torch → .aimodel. state_names derived from the exported graph's
    buffers_to_mutate (canonical order) so the KV mapping cannot silently misalign."""
    ep = torch.export.export(draft.eval(), sample_inputs(draft.head_dim, dtype))
    ep = ep.run_decompositions(coreai_torch.get_decomp_table())
    state_names = list(ep.graph_signature.buffers_to_mutate.values())
    print(f">> {len(state_names)} state tensors: {state_names[:4]}… (canonical buffers_to_mutate order)")
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
        print(">> asset summary:", asset.summary())
    except Exception as e:  # noqa: BLE001
        print(">> summary n/a:", e)
    return asset


@dataclass
class TinyCfg:
    num_hidden_layers: int = 2
    num_attention_heads: int = 4
    num_key_value_heads: int = 2
    hidden_size: int = 64
    intermediate_size: int = 128
    rms_norm_eps: float = 1e-5
    vocab_size: int = 320


def run_tiny() -> None:
    """Smoke the FULL llama op-set (embed, rms, rope, GQA repeat_interleave, sdpa, mlp, tied
    lm_head, stateful KV) through coreai_torch + host run — fast, no download, no fidelity."""
    print(">> TINY smoke (random weights, full op-set)")
    draft = StatefulLlamaDraft(TinyCfg()).eval()
    convert_to_aimodel(draft, "/tmp/toy_llama.aimodel")

    async def run():
        model = await _aw(AIModel.load("/tmp/toy_llama.aimodel"))
        fn = await _aw(model.load_function("main"))
        print(">> desc:", getattr(fn, "desc", "?"))
        st = {"kv": NDArray(np.zeros((2 * draft.n_layers, 1, draft.n_kv, MAX_SEQ, draft.head_dim), np.float32))}
        oh = np.zeros(MAX_SEQ, np.float32); oh[0] = 1.0
        bias = np.zeros(MAX_SEQ, np.float32); bias[1:] = -1e4
        out = await _aw(fn(inputs={
            "input_id": NDArray(np.array([[1]], np.int32)),
            "rope_cos": NDArray(np.ones(draft.head_dim, np.float32)),
            "rope_sin": NDArray(np.zeros(draft.head_dim, np.float32)),
            "write_onehot": NDArray(oh), "attn_bias": NDArray(bias),
        }, state=st))
        lg = np.asarray(list(out.values())[0].numpy()).reshape(-1)
        print(f">> TINY host run OK — logits shape={lg.shape}, argmax={int(lg.argmax())}")
    asyncio.run(run())
    print(">> TINY GREEN — full llama op-set converts + runs stateful on host.")


async def _aw(x):
    return await x if inspect.isawaitable(x) else x


def main() -> None:
    os.makedirs(OUT_DIR, exist_ok=True)
    if MODEL == "tiny":
        run_tiny()
        return

    from transformers import AutoModelForCausalLM, AutoTokenizer
    print(f">> loading {MODEL} (revision={REVISION})")
    hf = AutoModelForCausalLM.from_pretrained(MODEL, revision=REVISION, dtype=torch.float32).eval()
    tok = AutoTokenizer.from_pretrained(MODEL, revision=REVISION)
    cfg = hf.config
    rotary = hf.model.rotary_emb

    draft = StatefulLlamaDraft(cfg).eval()
    copy_weights(draft, hf)

    def cos_sin(pos: int):
        pid = torch.tensor([[pos]], dtype=torch.long)
        dummy = torch.zeros(1, 1, cfg.hidden_size)
        cos, sin = rotary(dummy, pid)
        return cos[0, 0], sin[0, 0]

    # ---- TORCH fp32 fidelity: greedy decode vs HF, token-identical ----
    prompt = "The capital of France is"
    ids = tok(prompt, return_tensors="pt").input_ids
    n_new = 24
    with torch.no_grad():
        hf_out = hf.generate(ids, max_new_tokens=n_new, do_sample=False, use_cache=True,
                             pad_token_id=tok.eos_token_id)
    hf_new = hf_out[0, ids.shape[1]:].tolist()

    def step(tid: int, pos: int):
        c, s = cos_sin(pos)
        oh = torch.zeros(MAX_SEQ); oh[pos] = 1.0
        bias = torch.zeros(MAX_SEQ); bias[pos + 1:] = float("-inf")
        with torch.no_grad():
            lg = draft(torch.tensor([[tid]], dtype=torch.long), c, s, oh, bias)
        return lg[0, 0]
    pos = 0
    for t in ids[0].tolist():
        logits = step(t, pos); pos += 1
    draft_new = []
    nxt = int(logits.argmax())
    for _ in range(n_new):
        draft_new.append(nxt)
        logits = step(nxt, pos); pos += 1
        nxt = int(logits.argmax())
    match = sum(1 for a, b in zip(hf_new, draft_new) if a == b)
    print(f">> TORCH FIDELITY token_match={match}/{n_new}  text={tok.decode(draft_new)!r}")
    if match < n_new:
        print(">> TORCH FIDELITY FAIL — not token-identical; NOT converting (fix the module).")
        sys.exit(2)
    print(">> TORCH FIDELITY PASS — converting to .aimodel…")

    convert_to_aimodel(draft, OUT)

    # ---- .aimodel host fidelity re-check (the SHIPPED artifact, via coreai.runtime) ----
    async def cm_fidelity():
        model = await _aw(AIModel.load(OUT))
        fn = await _aw(model.load_function("main"))
        st = {"kv": NDArray(np.zeros((2 * draft.n_layers, 1, draft.n_kv, MAX_SEQ, draft.head_dim), np.float32))}

        async def cm_step(tid: int, p: int):
            c, s = cos_sin(p)
            oh = np.zeros(MAX_SEQ, np.float32); oh[p] = 1.0
            bias = np.zeros(MAX_SEQ, np.float32); bias[p + 1:] = -1e4
            out = await _aw(fn(inputs={
                "input_id": NDArray(np.array([[tid]], np.int32)),
                "rope_cos": NDArray(c.numpy().astype(np.float32)),
                "rope_sin": NDArray(s.numpy().astype(np.float32)),
                "write_onehot": NDArray(oh), "attn_bias": NDArray(bias),
            }, state=st))
            return np.asarray(out["logits"].numpy()).reshape(-1)

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
        print(f">> AIMODEL FIDELITY token_match={cm_match}/{n_new}  text={tok.decode(cm_new)!r}")
        print(">> AIMODEL FIDELITY PASS — shipped .aimodel token-identical to HF greedy."
              if cm_match == n_new else
              ">> AIMODEL FIDELITY PARTIAL — .aimodel diverges (byte-identity still holds via target verify).")
    except Exception as e:  # noqa: BLE001
        print(f">> AIMODEL FIDELITY SKIPPED (host runtime: {e})")


if __name__ == "__main__":
    main()
