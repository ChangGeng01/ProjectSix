#!/usr/bin/env python3
"""LAYER-SPLIT stateful Llama-3.2-1B → N chained Apple **Core AI** `.aimodel` chunks.

Sibling of `Tools/llama_to_coreai.py`. The monolithic 16-layer fp16 `.aimodel` SIGABRTs the A19
CoreAI-0.4.0 `aned` (ANE) compiler: it exceeds a per-asset transformer-layer-count limit (~12–15;
empirically 8- and 12-layer assets compile + decode on the ANE, 16 does not). The math is fine —
the *single asset* is too big. So we SPLIT the 16 layers into chunks of ≤12 (default 8+8), each
emitted as its OWN `.aimodel`, and CHAIN them at decode time: chunk0 embeds the token and runs its
layers, hands the residual `hidden` to chunk1, … the last chunk applies final_norm + the tied
lm_head and returns `logits`. Each chunk carries its OWN fused KV state.

Because every chunk is the EXACT per-layer body of `StatefulLlamaDraft.forward` (same RMS, host-fed
RoPE, GQA repeat_interleave, attention, MLP, and crucially the one-hot KV write via
`torch.where(write_mask, X.expand(...), kv[...])` — NOT `cache*keep + X*oh`, which mis-lowers and
zeros GQA heads), the chain is MATHEMATICALLY IDENTICAL to the monolith and must reproduce HF greedy
token-for-token (24/24). The host fidelity gate below asserts exactly that.

NOTHING in `llama_to_coreai.py` is mutated — we import StatefulLlamaDraft / copy_weights /
sample_inputs / rotate_half / MAX_SEQ from it and reuse the verified copy_weights state-dict keys.

I/O CONTRACT (the Swift session matches this exactly):
  chunk0      inputs ["input_id"(1,1 int32), "rope_cos"(64 fp16), "rope_sin"(64 fp16),
                      "write_onehot"(512 fp16), "attn_bias"(512 fp16)]  state "kv"  output "hidden"(1,1,2048 fp16)
  middle      inputs ["hidden"(1,1,2048 fp16), rope_cos, rope_sin, write_onehot, attn_bias]  state "kv"  output "hidden"
  chunk_last  inputs ["hidden"(1,1,2048 fp16), rope_cos, rope_sin, write_onehot, attn_bias]  state "kv"  output "logits"(1,1,128256 fp16)

Run (NEUTRAL cwd — the coreai_torch pkg dir shadows stdlib _compression):
  cd /tmp && /tmp/coreai-cv/bin/python \
      /Users/.../BehavioralAISubstrate/Tools/llama_to_coreai_split.py
Out:  /tmp/draft_coreai/LlamaDraft1B_split88/chunk0.aimodel … chunkN-1.aimodel

SPLITS is module-level + configurable (default [8, 8]); must sum to 16, each ≤12.
  [12, 4]  → 2 chunks, first near the ~12 ceiling (proven to compile), tiny tail; fewer chain hops.
  [6, 5, 5]→ 3 chunks, max margin under the ANE limit; 2 hidden hand-offs instead of 1 (more host
             round-trips per token, but each asset is smallest → safest to compile).
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

# Reuse the verified module + weight-copy + sample-inputs from the repo converter (do NOT mutate it).
REPO = "/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate"
sys.path.insert(0, f"{REPO}/Tools")
from llama_to_coreai import (  # type: ignore  # noqa: E402
    StatefulLlamaDraft,
    copy_weights,
    rotate_half,
    MAX_SEQ,
)

MODEL = "unsloth/Llama-3.2-1B-Instruct"
REVISION = "5a8abab4a5d6f164389b1079fb721cfab8d7126c"
OUT_DIR = "/tmp/draft_coreai"

# ----------------------------------------------------------------------------- #
# SPLIT CONFIG — list of per-chunk layer counts. Must sum to n_layers (16) and  #
# each must be <= the ANE per-asset ceiling (~12). Default 8+8.                  #
# ----------------------------------------------------------------------------- #
SPLITS = [8, 8]
MAX_CHUNK_LAYERS = 12          # A19 CoreAI-0.4.0 ANE per-asset layer ceiling (8 & 12 verified, 16 SIGABRTs)
N_NEW = 24                     # tokens to compare vs HF greedy
PROMPT = "The capital of France is"


def splits_to_bounds(splits: list[int], n_layers: int) -> list[tuple[int, int]]:
    """Validate SPLITS and turn it into [start, end) bounds. Fail fast at the boundary."""
    if not splits:
        raise ValueError("SPLITS must be non-empty")
    if any(s <= 0 for s in splits):
        raise ValueError(f"SPLITS entries must be positive: {splits}")
    if sum(splits) != n_layers:
        raise ValueError(f"SPLITS {splits} sum to {sum(splits)}, expected {n_layers}")
    if any(s > MAX_CHUNK_LAYERS for s in splits):
        raise ValueError(f"SPLITS {splits} has a chunk > ANE ceiling {MAX_CHUNK_LAYERS}")
    bounds, cur = [], 0
    for s in splits:
        bounds.append((cur, cur + s))
        cur += s
    return bounds


# ----------------------------------------------------------------------------- #
# Chunk module — layers [start, end) with its OWN fused KV buffer.               #
#   is_first → owns `embed`, input is `input_id`.                                #
#   is_last  → owns `final_norm` + a tied `lm_head_weight` (COPY of embed.weight),#
#              output is `logits`; else output is the residual `hidden`.         #
# Per-layer body is byte-for-byte StatefulLlamaDraft.forward's loop body, with   #
# the chunk-local KV indexed from 0 (slot 2*(li-start), 2*(li-start)+1).         #
# ----------------------------------------------------------------------------- #
class LlamaChunk(nn.Module):
    def __init__(self, cfg, start: int, end: int, is_first: bool, is_last: bool) -> None:
        super().__init__()
        self.start = start
        self.end = end
        self.n_chunk_layers = end - start
        self.is_first = is_first
        self.is_last = is_last

        self.n_heads = cfg.num_attention_heads
        self.n_kv = cfg.num_key_value_heads
        self.head_dim = cfg.hidden_size // cfg.num_attention_heads
        self.hidden = cfg.hidden_size
        self.eps = cfg.rms_norm_eps
        self.rep = self.n_heads // self.n_kv
        self.scale = self.head_dim ** -0.5
        self.vocab_size = cfg.vocab_size

        L = self.n_chunk_layers
        H, KV, D, I = self.n_heads * self.head_dim, self.n_kv * self.head_dim, cfg.hidden_size, cfg.intermediate_size
        if is_first:
            self.embed = nn.Embedding(cfg.vocab_size, cfg.hidden_size)
        self.in_norm = nn.ParameterList([nn.Parameter(torch.ones(cfg.hidden_size)) for _ in range(L)])
        self.post_norm = nn.ParameterList([nn.Parameter(torch.ones(cfg.hidden_size)) for _ in range(L)])
        self.q = nn.ModuleList([nn.Linear(D, H, bias=False) for _ in range(L)])
        self.k = nn.ModuleList([nn.Linear(D, KV, bias=False) for _ in range(L)])
        self.v = nn.ModuleList([nn.Linear(D, KV, bias=False) for _ in range(L)])
        self.o = nn.ModuleList([nn.Linear(H, D, bias=False) for _ in range(L)])
        self.gate = nn.ModuleList([nn.Linear(D, I, bias=False) for _ in range(L)])
        self.up = nn.ModuleList([nn.Linear(D, I, bias=False) for _ in range(L)])
        self.down = nn.ModuleList([nn.Linear(I, D, bias=False) for _ in range(L)])
        if is_last:
            self.final_norm = nn.Parameter(torch.ones(cfg.hidden_size))
            # Tied lm_head: a real COPY of the embedding table [vocab, hidden]. The monolith does
            # `x @ self.embed.weight.t()`; here the last chunk has no embed, so it holds its own copy.
            self.register_buffer("lm_head_weight", torch.zeros(cfg.vocab_size, cfg.hidden_size))
        # ONE fused KV state for this chunk: slots [k0, v0, k1, v1, …] over its OWN layers only.
        self.register_buffer("kv", torch.zeros(2 * L, 1, self.n_kv, MAX_SEQ, self.head_dim))

    def _rms(self, x: torch.Tensor, w: torch.Tensor) -> torch.Tensor:
        # RMSNorm in fp32 on the (fp32) residual, gamma cast up; output cast to the weight dtype
        # (fp16) so it feeds the fp16 Linears. This mirrors HF's fp32 norm + the monolith's stability.
        xf = x.float()
        n = xf * torch.rsqrt(xf.pow(2).mean(-1, keepdim=True) + self.eps) * w.float()
        return n.to(w.dtype)

    def forward(self, x_or_id, rope_cos, rope_sin, write_onehot, attn_bias):
        oh = write_onehot.view(1, 1, MAX_SEQ, 1)
        # One-hot KV write via torch.where (→ coreai.broadcasting_where select), NOT `cache*keep + v*oh`
        # (broadcasting_mul mis-lowers the double-broadcast and zeros GQA heads — the 0/24 fidelity bug).
        write_mask = (oh > 0.5).expand(1, self.n_kv, MAX_SEQ, self.head_dim)
        cdt = self.in_norm[0].dtype                  # compute dtype (fp16 after .half())
        bias = attn_bias.view(1, 1, 1, MAX_SEQ).to(cdt)
        cos = rope_cos.view(1, 1, 1, self.head_dim).to(cdt)
        sin = rope_sin.view(1, 1, 1, self.head_dim).to(cdt)
        if self.is_first:
            # Residual stream `x` is kept in fp32 (the monolith never materialized a layer-boundary
            # tensor; fp16-rounding the residual at the split flips the argmax — fp32 residual + fp16
            # weights/matmuls reproduces the monolith's 24/24). embed table is fp16 → cast up.
            x = self.embed(x_or_id).float()      # input_id [1,1] -> fp32 hidden [1,1,2048]
        else:
            x = x_or_id.float()                  # fp32 hidden hand-off from the previous chunk
        kv = self.kv                             # read all this chunk's slots from the unmodified buffer
        new_slots = []
        for ci in range(self.n_chunk_layers):
            h = self._rms(x, self.in_norm[ci])   # fp16 normed input for the matmuls
            q = self.q[ci](h).view(1, 1, self.n_heads, self.head_dim).transpose(1, 2)
            k = self.k[ci](h).view(1, 1, self.n_kv, self.head_dim).transpose(1, 2)
            v = self.v[ci](h).view(1, 1, self.n_kv, self.head_dim).transpose(1, 2)
            half = self.head_dim // 2
            q = q * cos + rotate_half(q, half) * sin
            k = k * cos + rotate_half(k, half) * sin
            kc = torch.where(write_mask, k.expand(1, self.n_kv, MAX_SEQ, self.head_dim), kv[2 * ci])
            vc = torch.where(write_mask, v.expand(1, self.n_kv, MAX_SEQ, self.head_dim), kv[2 * ci + 1])
            new_slots.append(kc)
            new_slots.append(vc)
            kr = kc.repeat_interleave(self.rep, dim=1)
            vr = vc.repeat_interleave(self.rep, dim=1)
            scores = (q @ kr.transpose(-1, -2)) * self.scale + bias
            attn = torch.softmax(scores, dim=-1)
            out = (attn @ vr).transpose(1, 2).reshape(1, 1, self.n_heads * self.head_dim)
            x = x + self.o[ci](out).float()      # accumulate the residual in fp32
            h2 = self._rms(x, self.post_norm[ci])
            x = x + self.down[ci](F.silu(self.gate[ci](h2)) * self.up[ci](h2)).float()
        self.kv[:, :, :, :, :] = torch.stack(new_slots, dim=0)   # single fused write-back → one state
        if self.is_last:
            xn = self._rms(x, self.final_norm)   # fp16 normed
            return xn @ self.lm_head_weight.t()  # logits [1,1,vocab] (fp16 lm_head)
        # Emit the residual hand-off in fp32 so the next chunk receives a lossless boundary tensor.
        return x                                 # hidden [1,1,2048] fp32


def copy_chunk_weights(chunk: LlamaChunk, hf) -> None:
    """Copy HF weights for this chunk's layer window. Reuses the EXACT state-dict key scheme of
    llama_to_coreai.copy_weights, but indexed by absolute layer (start+ci) into the chunk's local
    slot ci. embed only on the first chunk; final_norm + tied lm_head copy only on the last."""
    sd = hf.state_dict()
    if chunk.is_first:
        chunk.embed.weight.data.copy_(sd["model.embed_tokens.weight"])
    for ci in range(chunk.n_chunk_layers):
        li = chunk.start + ci
        p = f"model.layers.{li}."
        chunk.in_norm[ci].data.copy_(sd[p + "input_layernorm.weight"])
        chunk.post_norm[ci].data.copy_(sd[p + "post_attention_layernorm.weight"])
        chunk.q[ci].weight.data.copy_(sd[p + "self_attn.q_proj.weight"])
        chunk.k[ci].weight.data.copy_(sd[p + "self_attn.k_proj.weight"])
        chunk.v[ci].weight.data.copy_(sd[p + "self_attn.v_proj.weight"])
        chunk.o[ci].weight.data.copy_(sd[p + "self_attn.o_proj.weight"])
        chunk.gate[ci].weight.data.copy_(sd[p + "mlp.gate_proj.weight"])
        chunk.up[ci].weight.data.copy_(sd[p + "mlp.up_proj.weight"])
        chunk.down[ci].weight.data.copy_(sd[p + "mlp.down_proj.weight"])
    if chunk.is_last:
        chunk.final_norm.data.copy_(sd["model.norm.weight"])
        # Tied lm_head == embed table (model.norm then x @ embed.weight.t() in the monolith).
        chunk.lm_head_weight.data.copy_(sd["model.embed_tokens.weight"])


def chunk_sample_inputs(chunk: LlamaChunk, dtype: torch.dtype = torch.float16):
    """One example arg-tuple for torch.export. First chunk: int input_id; else fp32 `hidden`
    (the boundary hand-off is fp32 — see forward). RoPE/onehot/bias are fp16 to match the fp16
    compute graph. Position 0 → attend slot 0 only."""
    bias = torch.cat([torch.zeros(1, dtype=dtype), torch.full((MAX_SEQ - 1,), -1e4, dtype=dtype)])
    if chunk.is_first:
        first = torch.zeros(1, 1, dtype=torch.long)
    else:
        first = torch.zeros(1, 1, chunk.hidden, dtype=torch.float32)   # fp32 hidden hand-off
    return (first, torch.zeros(chunk.head_dim, dtype=dtype),
            torch.zeros(chunk.head_dim, dtype=dtype), torch.zeros(MAX_SEQ, dtype=dtype), bias)


def convert_chunk_to_aimodel(chunk: LlamaChunk, idx: int, n_chunks: int, out_path: str) -> dict:
    """torch.export → run_decompositions → TorchConverter(state_names from buffers_to_mutate) →
    to_coreai().optimize().save_asset(). fp16 (.half) graph; first input name + output name depend
    on chunk position. Returns a dict with the resolved I/O contract + asset facts."""
    in0 = "input_id" if chunk.is_first else "hidden"
    out0 = "logits" if chunk.is_last else "hidden"
    chunk = chunk.eval().half()                          # fp16 weights + fp16 float buffers
    ep = torch.export.export(chunk, chunk_sample_inputs(chunk, torch.float16))
    ep = ep.run_decompositions(coreai_torch.get_decomp_table())
    state_names = list(ep.graph_signature.buffers_to_mutate.values())
    print(f">> chunk{idx}: {len(state_names)} state tensor(s): {state_names}  (buffers_to_mutate)")
    conv = coreai_torch.TorchConverter().add_exported_program(
        ep,
        input_names=[in0, "rope_cos", "rope_sin", "write_onehot", "attn_bias"],
        output_names=[out0],
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
    summary = ""
    try:
        summary = str(asset.summary())
        print(f">> chunk{idx} asset summary:", summary)
    except Exception as e:  # noqa: BLE001
        print(f">> chunk{idx} summary n/a:", e)
    mlirb = next(Path(out_path).glob("*.mlirb"))
    return {
        "idx": idx,
        "path": out_path,
        "input0": in0,
        "output0": out0,
        "state_name": state_names[0] if state_names else None,
        "state_names": state_names,
        "n_chunk_layers": chunk.n_chunk_layers,
        "mlirb": str(mlirb),
        "mlirb_bytes": mlirb.stat().st_size,
        "summary": summary,
    }


def convert_chunks_to_multifn_aimodel(chunks: list[LlamaChunk], out_path: str) -> dict:
    """Build ONE multi-function `.aimodel` with TWO entrypoints — stage0 + stage1 — from the 8+8
    chunk graphs, instead of two separate assets.

    The device CoreAI runtime SIGSEGVs when a 2nd `AIModel` is loaded into one process, so the two
    chunks must live in ONE asset (one `AIModel.load`, two `loadFunction`s). Each function still
    compiles independently (8 layers each) under the A19 ANE per-asset layer-count limit because the
    limit is per-entrypoint-graph, not per-asset-file.

    Steps:
      1. ONE `coreai_torch.TorchConverter()`. For each chunk idx: torch.export.export ->
         run_decompositions(get_decomp_table()) -> add_exported_program(ep, ..., entrypoint_name=f"stage{idx}").
      2. UNIQUE state name per function: pass `state_names=[f"kv{idx}"]` (override the buffer name) so
         stage0's state is "kv0" and stage1's is "kv1" — no cross-function state collision.
      3. `conv.to_coreai(entrypoints=[...])`; `prog.optimize()`; `prog.save_asset(Path(out_path))`.

    I/O CONTRACT (the Swift session matches this exactly — do NOT deviate):
      stage0  inputs ["input_id"(1,1 int32), "rope_cos"(64 fp16), "rope_sin"(64 fp16),
                      "write_onehot"(512 fp16), "attn_bias"(512 fp16)]  state "kv0"  output "hidden"(1,1,2048 fp32)
      stage1  inputs ["hidden"(1,1,2048 fp32), rope_cos, rope_sin, write_onehot, attn_bias]
                      state "kv1"  output "logits"(1,1,128256 fp32)
    """
    n_chunks = len(chunks)
    entrypoints = [f"stage{idx}" for idx in range(n_chunks)]
    conv = coreai_torch.TorchConverter()
    fn_infos = []
    for idx, chunk in enumerate(chunks):
        is_first = chunk.is_first
        is_last = chunk.is_last
        in0 = "input_id" if is_first else "hidden"
        out0 = "logits" if is_last else "hidden"
        ch = chunk.eval().half()                         # fp16 weights + fp16 float buffers
        ep = torch.export.export(ch, chunk_sample_inputs(ch, torch.float16))
        ep = ep.run_decompositions(coreai_torch.get_decomp_table())
        # Each chunk has exactly ONE fused KV buffer; override its state name to a UNIQUE per-fn name.
        buf_states = list(ep.graph_signature.buffers_to_mutate.values())
        if len(buf_states) != 1:
            raise RuntimeError(
                f"stage{idx}: expected exactly 1 mutated buffer (the fused KV), got {len(buf_states)}: "
                f"{buf_states}. The unique-state-name override assumes one KV buffer per chunk."
            )
        unique_state = f"kv{idx}"
        ep_name = f"stage{idx}"
        print(f">> {ep_name}: buffers_to_mutate={buf_states} -> override state_name=[{unique_state!r}] "
              f"in='{in0}' out='{out0}' layers={ch.n_chunk_layers}")
        conv = conv.add_exported_program(
            ep,
            input_names=[in0, "rope_cos", "rope_sin", "write_onehot", "attn_bias"],
            output_names=[out0],
            state_names=[unique_state],
            entrypoint_name=ep_name,
        )
        fn_infos.append({
            "entrypoint": ep_name,
            "input0": in0,
            "output0": out0,
            "state_name": unique_state,
            "n_chunk_layers": ch.n_chunk_layers,
        })

    prog = conv.to_coreai(entrypoints=entrypoints)
    prog.optimize()
    if Path(out_path).exists():
        import shutil
        shutil.rmtree(out_path)
    asset = prog.save_asset(Path(out_path))
    print(f">> SAVED MULTI-FN {out_path}  entrypoints={entrypoints}")
    summary = ""
    try:
        summary = str(asset.summary())
        print(">> multi-fn asset summary:", summary)
    except Exception as e:  # noqa: BLE001
        print(">> multi-fn summary n/a:", e)
    mlirb = next(Path(out_path).glob("*.mlirb"))
    return {
        "path": out_path,
        "entrypoints": entrypoints,
        "functions": fn_infos,
        "mlirb": str(mlirb),
        "mlirb_bytes": mlirb.stat().st_size,
        "summary": summary,
    }


async def _aw(x):
    return await x if inspect.isawaitable(x) else x


def main() -> None:
    Path(OUT_DIR).mkdir(parents=True, exist_ok=True)
    n_layers = 16
    bounds = splits_to_bounds(SPLITS, n_layers)
    tag = "".join(str(s) for s in SPLITS)
    split_dir = Path(OUT_DIR) / f"LlamaDraft1B_split{tag}"
    split_dir.mkdir(parents=True, exist_ok=True)
    n_chunks = len(bounds)
    print(f">> SPLITS={SPLITS} -> bounds={bounds}  ({n_chunks} chunks) -> {split_dir}")

    from transformers import AutoModelForCausalLM, AutoTokenizer
    print(f">> loading {MODEL} (revision={REVISION})")
    hf = AutoModelForCausalLM.from_pretrained(MODEL, revision=REVISION, dtype=torch.float32).eval()
    tok = AutoTokenizer.from_pretrained(MODEL, revision=REVISION)
    cfg = hf.config
    rotary = hf.model.rotary_emb
    assert cfg.num_hidden_layers == n_layers, f"expected {n_layers} layers, got {cfg.num_hidden_layers}"

    def cos_sin(pos: int):
        pid = torch.tensor([[pos]], dtype=torch.long)
        dummy = torch.zeros(1, 1, cfg.hidden_size)
        cos, sin = rotary(dummy, pid)
        return cos[0, 0], sin[0, 0]

    # ---- HF greedy reference ----
    ids = tok(PROMPT, return_tensors="pt").input_ids
    with torch.no_grad():
        hf_out = hf.generate(ids, max_new_tokens=N_NEW, do_sample=False, use_cache=True,
                             pad_token_id=tok.eos_token_id)
    hf_new = hf_out[0, ids.shape[1]:].tolist()
    print(f">> HF greedy ref: {tok.decode(hf_new)!r}")

    # ---- build + weight-copy each chunk, then convert each to its own fp16 .aimodel ----
    chunk_infos = []
    for idx, (s, e) in enumerate(bounds):
        is_first = idx == 0
        is_last = idx == n_chunks - 1
        chunk = LlamaChunk(cfg, s, e, is_first, is_last).eval()
        copy_chunk_weights(chunk, hf)
        out_path = str(split_dir / f"chunk{idx}.aimodel")
        print(f"\n================ chunk{idx}  layers[{s},{e})  first={is_first} last={is_last} ================")
        info = convert_chunk_to_aimodel(chunk, idx, n_chunks, out_path)
        chunk_infos.append(info)

    # ---- HOST FIDELITY GATE (R1): chain the chunk .aimodels in a greedy decode loop ----
    async def chained_fidelity():
        models, fns, states = [], [], []
        for idx, (s, e) in enumerate(bounds):
            m = await _aw(AIModel.load(chunk_infos[idx]["path"]))
            f = await _aw(m.load_function("main"))
            L = e - s
            models.append(m)
            fns.append(f)
            # Each chunk owns its OWN persistent kv state. The chunk graphs are fp16 (.half()), so the
            # state buffer is strictly fp16 — the runtime does NOT cast it (unlike the monolith path).
            states.append({"kv": NDArray(np.zeros((2 * L, 1, cfg.num_key_value_heads, MAX_SEQ,
                                                   cfg.hidden_size // cfg.num_attention_heads), np.float16))})

        async def chain_step(tid: int, p: int):
            c, s_ = cos_sin(p)
            oh = np.zeros(MAX_SEQ, np.float16); oh[p] = 1.0
            bias = np.zeros(MAX_SEQ, np.float16); bias[p + 1:] = -1e4
            rope_cos = NDArray(c.numpy().astype(np.float16))
            rope_sin = NDArray(s_.numpy().astype(np.float16))
            onehot = NDArray(oh)
            bias_nd = NDArray(bias)
            # chunk0: input_id -> hidden ; middle: hidden -> hidden ; last: hidden -> logits
            cur = NDArray(np.array([[tid]], np.int32))
            cur_name = "input_id"
            for idx in range(n_chunks):
                out = await _aw(fns[idx](inputs={
                    cur_name: cur,
                    "rope_cos": rope_cos, "rope_sin": rope_sin,
                    "write_onehot": onehot, "attn_bias": bias_nd,
                }, state=states[idx]))
                out_name = "logits" if idx == n_chunks - 1 else "hidden"
                cur = out[out_name]
                cur_name = "hidden"
            return np.asarray(cur.numpy()).reshape(-1)

        p = 0
        for t in ids[0].tolist():
            lg = await chain_step(t, p); p += 1
        chain_new = []
        nxt = int(lg.argmax())
        for _ in range(N_NEW):
            chain_new.append(nxt); lg = await chain_step(nxt, p); p += 1; nxt = int(lg.argmax())
        return chain_new

    chain_new = asyncio.run(chained_fidelity())
    chain_match = sum(1 for a, b in zip(hf_new, chain_new) if a == b)

    # ---- report ----
    print("\n================ SPLIT SUMMARY ================")
    print(f">> SPLITS={SPLITS}  chunks={n_chunks}  dir={split_dir}")
    for info in chunk_infos:
        print(f">> chunk{info['idx']}: layers={info['n_chunk_layers']} "
              f"in='{info['input0']}' out='{info['output0']}' state='{info['state_name']}' "
              f"main.mlirb={info['mlirb_bytes']/1e9:.3f} GB ({info['mlirb_bytes']} bytes)")
    print(f"\n>> CHAINED HOST token_match = {chain_match}/{N_NEW}")
    print(f">> chained text = {tok.decode(chain_new)!r}")
    print(f">> HF greedy    = {tok.decode(hf_new)!r}")
    if chain_match == N_NEW:
        print(">> SPLIT FIDELITY PASS — chained chunks are token-identical to HF greedy (24/24).")
    else:
        print(f">> SPLIT FIDELITY FAIL — {chain_match}/{N_NEW}; a chunk boundary or hidden hand-off is wrong.")
        sys.exit(2)

    # ========================================================================= #
    # MULTI-FUNCTION ASSET — ONE `.aimodel`, TWO entrypoints (stage0 + stage1). #
    # Built ALONGSIDE the per-chunk assets above (does not replace them). Only   #
    # the 2-chunk split maps onto the stage0/stage1 Swift contract.              #
    # ========================================================================= #
    if n_chunks != 2:
        print(f"\n>> SKIP multi-fn build — needs exactly 2 chunks (stage0+stage1); SPLITS={SPLITS} -> {n_chunks}.")
        return

    mfn_path = str(Path(OUT_DIR) / "LlamaDraft1B_mfn88.aimodel")
    print(f"\n================ MULTI-FN BUILD -> {mfn_path} ================")
    # Fresh chunks (the per-chunk loop above .half()-ed its instances in place).
    mfn_chunks = []
    for idx, (s, e) in enumerate(bounds):
        ch = LlamaChunk(cfg, s, e, idx == 0, idx == n_chunks - 1).eval()
        copy_chunk_weights(ch, hf)
        mfn_chunks.append(ch)
    mfn_info = convert_chunks_to_multifn_aimodel(mfn_chunks, mfn_path)

    # ---- MULTI-FN HOST FIDELITY GATE: ONE AIModel.load, TWO load_function()s ----
    async def multifn_fidelity():
        m = await _aw(AIModel.load(mfn_info["path"]))
        names = list(m.function_names)
        print(f">> multi-fn function_names = {names}")
        fns, states, fn_descs = [], [], {}
        head_dim = cfg.hidden_size // cfg.num_attention_heads
        for idx, (s, e) in enumerate(bounds):
            ep_name = f"stage{idx}"
            f = await _aw(m.load_function(ep_name))
            fns.append(f)
            try:
                fn_descs[ep_name] = str(f.desc)
            except Exception as e_:  # noqa: BLE001
                fn_descs[ep_name] = f"<desc n/a: {e_}>"
            L = e - s
            # Each function owns its OWN persistent kv state under its UNIQUE name kv{idx}.
            states.append({f"kv{idx}": NDArray(np.zeros(
                (2 * L, 1, cfg.num_key_value_heads, MAX_SEQ, head_dim), np.float16))})

        async def mfn_step(tid: int, p: int):
            c, s_ = cos_sin(p)
            oh = np.zeros(MAX_SEQ, np.float16); oh[p] = 1.0
            bias = np.zeros(MAX_SEQ, np.float16); bias[p + 1:] = -1e4
            rope_cos = NDArray(c.numpy().astype(np.float16))
            rope_sin = NDArray(s_.numpy().astype(np.float16))
            onehot = NDArray(oh)
            bias_nd = NDArray(bias)
            # stage0: input_id (+state kv0) -> hidden ; stage1: hidden (+state kv1) -> logits
            cur = NDArray(np.array([[tid]], np.int32))
            cur_name = "input_id"
            for idx in range(n_chunks):
                out = await _aw(fns[idx](inputs={
                    cur_name: cur,
                    "rope_cos": rope_cos, "rope_sin": rope_sin,
                    "write_onehot": onehot, "attn_bias": bias_nd,
                }, state=states[idx]))
                out_name = "logits" if idx == n_chunks - 1 else "hidden"
                cur = out[out_name]
                cur_name = "hidden"
            return np.asarray(cur.numpy()).reshape(-1)

        p = 0
        for t in ids[0].tolist():
            lg = await mfn_step(t, p); p += 1
        mfn_new = []
        nxt = int(lg.argmax())
        for _ in range(N_NEW):
            mfn_new.append(nxt); lg = await mfn_step(nxt, p); p += 1; nxt = int(lg.argmax())
        return names, fn_descs, mfn_new

    fn_names, fn_descs, mfn_new = asyncio.run(multifn_fidelity())
    mfn_match = sum(1 for a, b in zip(hf_new, mfn_new) if a == b)

    print("\n================ MULTI-FN SUMMARY ================")
    print(f">> asset          = {mfn_info['path']}")
    print(f">> main.mlirb      = {mfn_info['mlirb_bytes']/1e9:.3f} GB ({mfn_info['mlirb_bytes']} bytes)")
    print(f">> function_names  = {fn_names}")
    for ep, fi in zip(mfn_info["entrypoints"], mfn_info["functions"]):
        print(f">> {ep}: in='{fi['input0']}' out='{fi['output0']}' state='{fi['state_name']}' "
              f"layers={fi['n_chunk_layers']}")
        print(f"     desc = {fn_descs.get(ep)}")
    print(f"\n>> MULTI-FN HOST token_match = {mfn_match}/{N_NEW}")
    print(f">> multi-fn text  = {tok.decode(mfn_new)!r}")
    print(f">> HF greedy      = {tok.decode(hf_new)!r}")
    if mfn_match == N_NEW:
        print(">> MULTI-FN FIDELITY PASS — one asset, two functions, token-identical to HF greedy (24/24).")
    else:
        print(f">> MULTI-FN FIDELITY FAIL — {mfn_match}/{N_NEW}; a stage boundary or per-fn state is wrong.")
        sys.exit(3)


if __name__ == "__main__":
    main()
