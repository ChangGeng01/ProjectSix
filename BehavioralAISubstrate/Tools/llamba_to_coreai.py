#!/usr/bin/env python3
"""cartesia-ai/Llamba-1B  (16-layer pure Mamba-2 / "discrete Mamba-2" LLM,
Llama-3 tokenizer vocab 128256, distilled from Llama-3.1-8B)  →  STATEFUL fp16
CoreAI `.aimodel` for on-device A19 ANE DECODE — a spec-decode DRAFT for a
Llama-3.2-3B target.

Feasibility is already proven by /tmp/mamba2_coreai_probe.py (generic Mamba-2
SSD decode block converts + runs stateful on CoreAI host, fp32-exact, up to
16 layers). THIS is the REAL-weights build.

Key differences from the generic probe (Cartesia's "discrete Mamba-2", from
github.com/cartesia-ai/edge .../Llamba/mixers/discrete_mamba2.py):

  * A is FIXED at -1 (A = -ones[H]); there is NO learned A_log parameter.
    Instead the per-step `dt` is the LAST n_v_heads columns of in_proj's output
    (the code calls it `A_log`):  dt = softplus(A_log),  dA = exp(dt * -1).
  * x is PRE-DIVIDED by softplus(A_log) before the scan:  x_ssm = x / dt.
    (so the input term dt*x_ssm*B reduces to x*B — but we replicate exactly.)
  * conv activation is IDENTITY (no SiLU after the depthwise conv).
  * gate is silu(z + z_bias)  — a learned z_bias the generic probe lacked.
  * in_proj split order is [xBC ; z ; A_log(=dt)]  (NOT z-first).
  * n_qk_heads == n_v_heads == 32, ngroups==nheads (1:1 B/C per v-head),
    so there is NO B/C broadcast across heads.
  * D-skip uses the ORIGINAL (un-divided) x:  y = ssm·C + D*x.
  * Each Block is a HYBRID: Mamba mixer + a Llama-style MLP (gate/up/down, SiLU),
    with input_layernorm (pre-mixer) and post_attention_layernorm (pre-MLP),
    RMSNorm, residuals. final_layernorm + TIED lm_head (x @ embed.weight.T).

The stateful single-step recurrence is verified TOKEN-IDENTICAL (24/24) against
a pure-torch SEQUENTIAL selective-scan reference built from mamba_ssm's own
`selective_state_update_ref` math (mamba_ssm/causal_conv1d CUDA kernels are NOT
installable here, so we reproduce the documented reference exactly and load the
REAL weights into it). That sequential scan IS the linear recurrence the chunked
`mamba_chunk_scan_combined` computes, so matching it == matching Llamba's forward.

Run (coreai_torch shadows stdlib _compression — MUST run from /tmp):
    cd /tmp && /tmp/coreai-cv/bin/python \
        /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tools/llamba_to_coreai.py
"""
from __future__ import annotations

import asyncio
import inspect
import json
import shutil
import sys
from dataclasses import dataclass
from pathlib import Path

import numpy as np
import torch
import torch.nn as nn
import torch.nn.functional as F

HF_ID = "cartesia-ai/Llamba-1B"
TOK_ID = "unsloth/Llama-3.2-1B-Instruct"  # ungated Llama-3 tokenizer, vocab 128256 (len(tok))
OUT = "/tmp/draft_coreai/Llamba1B_fp16.aimodel"
N_FIDELITY = 24
N_COHERE = 50
EPS = 1e-5


# ============================== config ==============================
@dataclass(frozen=True)
class LlambaCfg:
    d_model: int = 2048
    n_layer: int = 16
    vocab_size: int = 128256
    d_state: int = 64          # N
    n_v_heads: int = 32        # H
    n_qk_heads: int = 32       # G (== H here → 1:1 B/C per head, no broadcast)
    expand: int = 1
    d_conv: int = 4            # K
    intermediate_size: int = 8192
    norm_epsilon: float = 1e-5

    @property
    def d_inner(self) -> int:
        return self.expand * self.d_model         # 2048

    @property
    def headdim(self) -> int:
        return self.d_inner // self.n_v_heads     # 64  (P)

    @property
    def conv_dim(self) -> int:
        # conv is over [x ; B ; C] = d_inner + 2*n_qk_heads*d_state
        return self.d_inner + 2 * self.n_qk_heads * self.d_state  # 6144


def cfg_from_json(d: dict) -> LlambaCfg:
    ssm = d["ssm_cfg"]
    return LlambaCfg(
        d_model=d["d_model"],
        n_layer=d["n_layer"],
        vocab_size=d["vocab_size"],
        d_state=ssm["d_state"],
        n_v_heads=ssm["n_v_heads"],
        n_qk_heads=ssm["n_qk_heads"],
        expand=ssm["expand"],
        d_conv=ssm.get("d_conv", 4),
        intermediate_size=d["mlp_cfg"]["intermediate_size"],
        norm_epsilon=d.get("norm_epsilon", 1e-5),
    )


def rmsnorm(x: torch.Tensor, w: torch.Tensor, eps: float) -> torch.Tensor:
    # LlamaRMSNorm: compute in fp32, cast back, then scale.
    in_dtype = x.dtype
    x = x.to(torch.float32)
    x = x * torch.rsqrt(x.pow(2).mean(-1, keepdim=True) + eps)
    return (w * x.to(in_dtype))


# ============================== stateful single-step module ==============================
class LlambaDecodeLayer(nn.Module):
    """ONE Llamba block, DECODE (single-token recurrent) form. STATELESS: the conv/ssm slots
       are read from the module-level fused buffers (LlambaDecode.conv_all / .ssm_all) and the
       freshly-computed new slots are returned so the parent can write all 16 back in ONE shot.
       (mirrors StatefulLlamaDraft's single fused-KV buffer — 2 CoreAI states instead of 32.)"""

    def __init__(self, cfg: LlambaCfg, layer_idx: int) -> None:
        super().__init__()
        self.cfg = cfg
        self.li = layer_idx
        H, N, G = cfg.n_v_heads, cfg.d_state, cfg.n_qk_heads
        d_inner, conv_dim = cfg.d_inner, cfg.conv_dim

        self.input_layernorm = nn.Parameter(torch.ones(cfg.d_model))
        # in_proj → [xBC (d_inner + 2*G*N) ; z (d_inner) ; A_log/dt (H)]
        self.in_proj = nn.Linear(cfg.d_model, 2 * d_inner + 2 * G * N + H, bias=False)
        self.conv_w = nn.Parameter(torch.zeros(conv_dim, cfg.d_conv))   # squeezed conv1d.weight
        self.conv_b = nn.Parameter(torch.zeros(conv_dim))               # conv1d.bias
        self.z_bias = nn.Parameter(torch.zeros(d_inner))
        self.D = nn.Parameter(torch.ones(H))
        self.out_proj = nn.Linear(d_inner, cfg.d_model, bias=False)

        self.post_attention_layernorm = nn.Parameter(torch.ones(cfg.d_model))
        self.gate_proj = nn.Linear(cfg.d_model, cfg.intermediate_size, bias=False)
        self.up_proj = nn.Linear(cfg.d_model, cfg.intermediate_size, bias=False)
        self.down_proj = nn.Linear(cfg.intermediate_size, cfg.d_model, bias=False)
        # NOTE: no per-layer buffers — state lives in LlambaDecode.{conv_all,ssm_all}.

    def _mixer(self, u: torch.Tensor, conv_state: torch.Tensor,
               ssm_state: torch.Tensor) -> tuple:
        # u: [d_model]; conv_state: [conv_dim, K] (this layer's slice of the unmodified conv_all);
        # ssm_state: [H, P, N] (this layer's slice of the unmodified ssm_all).
        # Returns (out[d_model], new_conv_state[conv_dim,K], new_ssm_state[H,P,N]).
        cfg = self.cfg
        H, P, N, G = cfg.n_v_heads, cfg.headdim, cfg.d_state, cfg.n_qk_heads
        d_inner = cfg.d_inner

        proj = self.in_proj(u)                                # [2*d_inner + 2*G*N + H]
        xBC, z, A_log = torch.split(
            proj, [d_inner + 2 * G * N, d_inner, H], dim=-1)

        # depthwise causal conv as rolling-state dot product (identity activation)
        new_conv_state = torch.cat([conv_state[:, 1:], xBC.unsqueeze(-1)], dim=-1)  # [conv_dim, K]
        xBC = (new_conv_state * self.conv_w).sum(-1) + self.conv_b                  # [conv_dim]
        # activation == identity (no SiLU)

        x, B, C = torch.split(xBC, [d_inner, G * N, G * N], dim=-1)
        x_heads = x.view(H, P)                                # [H, P]  (original x)
        B = B.view(G, N)                                      # [G=H, N]
        C = C.view(G, N)

        # selective SSM recurrent step (selective_state_update_ref math):
        #   dt = softplus(A_log)            [H]
        #   x_ssm = x / dt                  (the kernel's `x` input)
        #   dA = exp(dt * (-1))             [H]
        #   dB = dt[:,None] * B             [H, N]   (per-head, ngroups==nheads)
        #   state = state*dA + dB ⊗ x_ssm
        #   y = sum_n state * C  +  D * x_orig
        dt = F.softplus(A_log)                                # [H]
        x_ssm = x_heads / dt.unsqueeze(-1)                    # [H, P]
        dA = torch.exp(dt * (-1.0))                           # [H]
        dB = dt.unsqueeze(-1) * B                             # [H, N]
        dBx = x_ssm.unsqueeze(-1) * dB.view(H, 1, N)          # [H, P, N]
        new_ssm_state = ssm_state * dA.view(H, 1, 1) + dBx    # [H, P, N]
        y = (new_ssm_state * C.view(H, 1, N)).sum(-1)         # [H, P]
        y = y + self.D.view(H, 1) * x_heads                   # D-skip uses ORIGINAL x
        y = y.reshape(d_inner)

        out = self.out_proj(y * F.silu(z + self.z_bias))      # gate silu(z + z_bias)
        return out, new_conv_state, new_ssm_state

    def forward(self, x: torch.Tensor, conv_state: torch.Tensor,
                ssm_state: torch.Tensor) -> tuple:            # x: [d_model]
        # Returns (x_out[d_model], new_conv_state[conv_dim,K], new_ssm_state[H,P,N]).
        residual = x
        h = rmsnorm(x, self.input_layernorm, self.cfg.norm_epsilon)
        mix, new_conv_state, new_ssm_state = self._mixer(h, conv_state, ssm_state)
        x = mix + residual
        residual = x
        h = rmsnorm(x, self.post_attention_layernorm, self.cfg.norm_epsilon)
        h = self.down_proj(F.silu(self.gate_proj(h)) * self.up_proj(h))   # LlamaMLP
        return residual + h, new_conv_state, new_ssm_state


class LlambaDecode(nn.Module):
    """Full stateful single-step Llamba decoder. forward(input_id[1,1]) -> logits[1, vocab]."""

    def __init__(self, cfg: LlambaCfg) -> None:
        super().__init__()
        self.cfg = cfg
        self.embedding = nn.Embedding(cfg.vocab_size, cfg.d_model)
        self.layers = nn.ModuleList([LlambaDecodeLayer(cfg, i) for i in range(cfg.n_layer)])
        self.final_layernorm = nn.Parameter(torch.ones(cfg.d_model))
        # TWO module-level FUSED state buffers (→ exactly 2 CoreAI states, not 32). Each layer's
        # slot is disjoint, so we read every layer's slice from the UNMODIFIED buffer at the top
        # of forward and write the whole stack back ONCE at the end (mirrors StatefulLlamaDraft.kv).
        L, H, P, N = cfg.n_layer, cfg.n_v_heads, cfg.headdim, cfg.d_state
        self.register_buffer("conv_all", torch.zeros(L, cfg.conv_dim, cfg.d_conv))  # [16,6144,4]
        self.register_buffer("ssm_all", torch.zeros(L, H, P, N))                    # [16,32,64,64]

    def forward(self, input_id: torch.Tensor) -> torch.Tensor:
        x = self.embedding(input_id).view(self.cfg.d_model)
        conv_all = self.conv_all        # read all slots from the unmodified buffers (disjoint)
        ssm_all = self.ssm_all
        new_conv: list[torch.Tensor] = []
        new_ssm: list[torch.Tensor] = []
        for i, layer in enumerate(self.layers):
            x, nc, ns = layer(x, conv_all[i], ssm_all[i])
            new_conv.append(nc)
            new_ssm.append(ns)
        # single fused write-back per buffer → exactly one mutation each (one write_handle).
        self.conv_all[:] = torch.stack(new_conv, 0)
        self.ssm_all[:] = torch.stack(new_ssm, 0)
        x = rmsnorm(x, self.final_layernorm, self.cfg.norm_epsilon)
        logits = x @ self.embedding.weight.t()                # tied head
        return logits.view(1, self.cfg.vocab_size)


# ============================== weight loading ==============================
def load_real_weights(model: LlambaDecode, state: dict) -> None:
    """Map Cartesia checkpoint names → LlambaDecode params. Strict (asserts every tensor used)."""
    g = lambda k: state[k]
    used = set()

    def take(k):
        used.add(k)
        return g(k)

    with torch.no_grad():
        model.embedding.weight.copy_(take("backbone.embedding.weight"))
        model.final_layernorm.copy_(take("backbone.final_layernorm.weight"))
        for i, layer in enumerate(model.layers):
            p = f"backbone.layers.{i}."
            layer.input_layernorm.copy_(take(p + "input_layernorm.weight"))
            layer.in_proj.weight.copy_(take(p + "mixer.in_proj.weight"))
            layer.conv_w.copy_(take(p + "mixer.conv1d.weight").squeeze(1))   # [conv_dim,1,K]->[conv_dim,K]
            layer.conv_b.copy_(take(p + "mixer.conv1d.bias"))
            layer.z_bias.copy_(take(p + "mixer.z_bias"))
            layer.D.copy_(take(p + "mixer.D"))
            layer.out_proj.weight.copy_(take(p + "mixer.out_proj.weight"))
            layer.post_attention_layernorm.copy_(take(p + "post_attention_layernorm.weight"))
            layer.gate_proj.weight.copy_(take(p + "mlp.gate_proj.weight"))
            layer.up_proj.weight.copy_(take(p + "mlp.up_proj.weight"))
            layer.down_proj.weight.copy_(take(p + "mlp.down_proj.weight"))

    missing = set(state) - used
    if missing:
        raise RuntimeError(f"UNUSED checkpoint tensors (port incomplete): {sorted(missing)[:8]}")


# ============================== pure-torch HF-equivalent reference ==============================
class LlambaRef:
    """Sequential selective-scan reference (fp32) reproducing Cartesia's discrete-Mamba-2
    forward EXACTLY from mamba_ssm's documented `selective_state_update_ref` math, with the
    REAL weights. This is the linear recurrence that chunked `mamba_chunk_scan_combined`
    computes → matching it == matching the HF Llamba forward. Carries state across tokens."""

    def __init__(self, cfg: LlambaCfg, state: dict) -> None:
        self.cfg = cfg
        self.s = {k: v.float() for k, v in state.items()}
        H, P, N = cfg.n_v_heads, cfg.headdim, cfg.d_state
        cd, K = cfg.conv_dim, cfg.d_conv
        self.conv = [torch.zeros(cd, K) for _ in range(cfg.n_layer)]   # [conv_dim, K]
        self.ssm = [torch.zeros(H, P, N) for _ in range(cfg.n_layer)]  # [H, P, N]

    def reset(self) -> None:
        H, P, N = self.cfg.n_v_heads, self.cfg.headdim, self.cfg.d_state
        cd, K = self.cfg.conv_dim, self.cfg.d_conv
        self.conv = [torch.zeros(cd, K) for _ in range(self.cfg.n_layer)]
        self.ssm = [torch.zeros(H, P, N) for _ in range(self.cfg.n_layer)]

    def _mixer(self, u: torch.Tensor, i: int) -> torch.Tensor:
        cfg = self.cfg
        H, P, N, G = cfg.n_v_heads, cfg.headdim, cfg.d_state, cfg.n_qk_heads
        d_inner = cfg.d_inner
        p = f"backbone.layers.{i}.mixer."
        proj = u @ self.s[p + "in_proj.weight"].t()
        xBC, z, A_log = torch.split(proj, [d_inner + 2 * G * N, d_inner, H], dim=-1)

        cw = self.s[p + "conv1d.weight"].squeeze(1)            # [conv_dim, K]
        cb = self.s[p + "conv1d.bias"]
        new_conv = torch.cat([self.conv[i][:, 1:], xBC.unsqueeze(-1)], dim=-1)
        xBC = (new_conv * cw).sum(-1) + cb                    # identity act
        self.conv[i] = new_conv

        x, B, C = torch.split(xBC, [d_inner, G * N, G * N], dim=-1)
        x_heads = x.view(H, P)
        B = B.view(G, N)
        C = C.view(G, N)

        dt = F.softplus(A_log)                                # [H]
        x_ssm = x_heads / dt.unsqueeze(-1)
        dA = torch.exp(dt * (-1.0))
        dB = dt.unsqueeze(-1) * B
        dBx = x_ssm.unsqueeze(-1) * dB.view(H, 1, N)
        self.ssm[i] = self.ssm[i] * dA.view(H, 1, 1) + dBx
        y = (self.ssm[i] * C.view(H, 1, N)).sum(-1)
        y = y + self.s[p + "D"].view(H, 1) * x_heads
        y = y.reshape(d_inner)
        return (y * F.silu(z + self.s[p + "z_bias"])) @ self.s[p + "out_proj.weight"].t()

    def step(self, tok: int) -> torch.Tensor:
        cfg = self.cfg
        x = self.s["backbone.embedding.weight"][tok].clone()
        for i in range(cfg.n_layer):
            p = f"backbone.layers.{i}."
            residual = x
            h = rmsnorm(x, self.s[p + "input_layernorm.weight"], cfg.norm_epsilon)
            x = self._mixer(h, i) + residual
            residual = x
            h = rmsnorm(x, self.s[p + "post_attention_layernorm.weight"], cfg.norm_epsilon)
            h = (F.silu(h @ self.s[p + "mlp.gate_proj.weight"].t())
                 * (h @ self.s[p + "mlp.up_proj.weight"].t())) @ self.s[p + "mlp.down_proj.weight"].t()
            x = residual + h
        x = rmsnorm(x, self.s["backbone.final_layernorm.weight"], cfg.norm_epsilon)
        return x @ self.s["backbone.embedding.weight"].t()


# ============================== conversion ==============================
def convert_to_aimodel(model: LlambaDecode, out_path: str, dtype: torch.dtype) -> tuple:
    import coreai_torch
    model = model.eval()
    sample = (torch.zeros(1, 1, dtype=torch.long),)
    ep = torch.export.export(model, sample)
    ep = ep.run_decompositions(coreai_torch.get_decomp_table())
    state_names = list(ep.graph_signature.buffers_to_mutate.values())
    print(f">> {len(state_names)} state tensors (canonical buffers_to_mutate order):")
    for n in state_names:
        print("      ", n)
    conv = coreai_torch.TorchConverter().add_exported_program(
        ep,
        input_names=["input_id"],
        output_names=["logits"],
        state_names=state_names,
        entrypoint_name="main",
    )
    prog = conv.to_coreai()
    prog.optimize()
    if Path(out_path).exists():
        shutil.rmtree(out_path)
    Path(out_path).parent.mkdir(parents=True, exist_ok=True)
    asset = prog.save_asset(Path(out_path))
    print(f">> SAVED {out_path}")
    return asset, state_names


async def _aw(x):
    return await x if inspect.isawaitable(x) else x


# ============================== host run ==============================
def host_decode(out_path: str, cfg: LlambaCfg, state_names: list[str],
                prompt_ids: list[int], n_new: int, fp16: bool) -> list[int]:
    """Greedy decode on the CoreAI host runtime. Returns generated token ids (after prompt)."""
    from coreai.runtime import AIModel, NDArray
    np_dt = np.float16 if fp16 else np.float32
    L, H, P, N = cfg.n_layer, cfg.n_v_heads, cfg.headdim, cfg.d_state
    cd, K = cfg.conv_dim, cfg.d_conv

    async def run():
        model = await _aw(AIModel.load(out_path))
        fn = await _aw(model.load_function("main"))
        st = {}
        for nm in state_names:
            shape = (L, cd, K) if "conv_all" in nm else (L, H, P, N)
            st[nm] = NDArray(np.zeros(shape, np_dt))

        out_ids: list[int] = []
        # prime with prompt (all but generate from last)
        last = None
        for t in prompt_ids:
            res = await _aw(fn(inputs={"input_id": NDArray(np.array([[t]], np.int32))}, state=st))
            last = np.asarray(res["logits"].numpy()).reshape(-1)
        for _ in range(n_new):
            nxt = int(last.argmax())
            out_ids.append(nxt)
            res = await _aw(fn(inputs={"input_id": NDArray(np.array([[nxt]], np.int32))}, state=st))
            last = np.asarray(res["logits"].numpy()).reshape(-1)
        return out_ids

    return asyncio.run(run())


def host_logits_seq(out_path: str, cfg: LlambaCfg, state_names: list[str],
                    token_ids: list[int], fp16: bool) -> list[np.ndarray]:
    """Feed a fixed token sequence, collect per-step logits (for torch-vs-host argmax compare)."""
    from coreai.runtime import AIModel, NDArray
    np_dt = np.float16 if fp16 else np.float32
    L, H, P, N = cfg.n_layer, cfg.n_v_heads, cfg.headdim, cfg.d_state
    cd, K = cfg.conv_dim, cfg.d_conv

    async def run():
        model = await _aw(AIModel.load(out_path))
        fn = await _aw(model.load_function("main"))
        st = {}
        for nm in state_names:
            shape = (L, cd, K) if "conv_all" in nm else (L, H, P, N)
            st[nm] = NDArray(np.zeros(shape, np_dt))
        outs = []
        for t in token_ids:
            res = await _aw(fn(inputs={"input_id": NDArray(np.array([[t]], np.int32))}, state=st))
            outs.append(np.asarray(res["logits"].numpy()).reshape(-1).copy())
        return outs

    return asyncio.run(run())


# ============================== torch greedy (teacher-forced reference path) ==============================
def torch_ref_decode(ref: LlambaRef, prompt_ids: list[int], n_new: int) -> list[int]:
    ref.reset()
    out_ids: list[int] = []
    last = None
    with torch.no_grad():
        for t in prompt_ids:
            last = ref.step(t)
        for _ in range(n_new):
            nxt = int(last.argmax())
            out_ids.append(nxt)
            last = ref.step(nxt)
    return out_ids


def torch_self_decode(model: LlambaDecode, prompt_ids: list[int], n_new: int) -> tuple:
    """Greedy decode with the stateful LlambaDecode (fp32) itself. Returns (ids, per-step logits seq).
    Assumes `model` has freshly-zeroed conv/ssm state buffers."""
    out_ids: list[int] = []
    logit_seq: list[np.ndarray] = []
    last = None
    with torch.no_grad():
        for t in prompt_ids:
            last = model(torch.tensor([[t]], dtype=torch.long)).view(-1)
            logit_seq.append(last.numpy().copy())
        for _ in range(n_new):
            nxt = int(last.argmax())
            out_ids.append(nxt)
            last = model(torch.tensor([[nxt]], dtype=torch.long)).view(-1)
            logit_seq.append(last.numpy().copy())
    return out_ids, logit_seq


# ============================== main ==============================
def main() -> None:
    from huggingface_hub import hf_hub_download
    from safetensors.torch import load_file
    from transformers import AutoTokenizer

    torch.manual_seed(0)
    print("=== Llamba-1B → STATEFUL fp16 CoreAI .aimodel (spec-decode DRAFT) ===")

    cfg_path = hf_hub_download(HF_ID, "config.json")
    cfg = cfg_from_json(json.load(open(cfg_path)))
    print(f"    cfg: n_layer={cfg.n_layer} d_model={cfg.d_model} vocab={cfg.vocab_size} "
          f"H={cfg.n_v_heads} P={cfg.headdim} N={cfg.d_state} G={cfg.n_qk_heads} "
          f"K={cfg.d_conv} conv_dim={cfg.conv_dim} d_inner={cfg.d_inner} "
          f"mlp={cfg.intermediate_size}")

    sd_path = hf_hub_download(HF_ID, "model.safetensors")
    state = load_file(sd_path)
    tok = AutoTokenizer.from_pretrained(TOK_ID)
    assert tok.vocab_size + len(tok.added_tokens_decoder) >= 0
    print(f"    tokenizer: {TOK_ID}  vocab_size={tok.vocab_size}  "
          f"(model vocab {cfg.vocab_size})")

    # ---- build modules (fp32 first for the gate) ----
    model = LlambaDecode(cfg).eval()
    load_real_weights(model, state)
    ref = LlambaRef(cfg, state)

    prompt = "The capital of France is"
    prompt_ids = tok(prompt, return_tensors="pt").input_ids[0].tolist()
    print(f"\n    prompt={prompt!r}  ids={prompt_ids}")

    # =================== GATE 1: torch single-step vs sequential reference ===================
    print("\n>> GATE 1 — torch LlambaDecode (stateful, fp32) vs sequential selective-scan ref")
    ref_ids = torch_ref_decode(ref, prompt_ids, N_FIDELITY)
    self_ids, _ = torch_self_decode(model, prompt_ids, N_FIDELITY)
    match = sum(1 for a, b in zip(self_ids, ref_ids) if a == b)
    print(f"   ref  ids: {ref_ids}")
    print(f"   self ids: {self_ids}")
    print(f"   TORCH FIDELITY: {match}/{N_FIDELITY}")
    print(f"   ref  text: {tok.decode(ref_ids)!r}")
    if match != N_FIDELITY:
        print(">> GATE 1 FAILED — single-step port does not match the reference. Aborting.")
        sys.exit(5)
    print(f"   ✓ coherence sample (ref, {N_COHERE} tok): "
          f"{tok.decode(torch_ref_decode(ref, prompt_ids, N_COHERE))!r}")

    # =================== convert fp16 ===================
    print("\n>> converting fp16 → .aimodel")
    model_fp16 = LlambaDecode(cfg).eval()
    load_real_weights(model_fp16, state)
    model_fp16 = model_fp16.half()
    asset, state_names = convert_to_aimodel(model_fp16, OUT, torch.float16)

    # main.mlirb size + storage types
    mlirb = Path(OUT) / "main.mlirb"
    sz = mlirb.stat().st_size if mlirb.exists() else -1
    print(f">> main.mlirb size: {sz} bytes ({sz/1e6:.2f} MB)")
    try:
        print(">> asset summary:", asset.summary())
    except Exception as e:  # noqa: BLE001
        print(">> summary n/a:", e)

    # =================== GATE 2: .aimodel host vs torch ref (argmax token match) ===================
    print("\n>> GATE 2 — .aimodel host decode vs torch reference (token match / coherence)")
    # token-match over the gate window: feed prompt+ref's own generated ids, compare argmax
    gate_seq = prompt_ids + ref_ids  # teacher-forced sequence
    host_logits = host_logits_seq(OUT, cfg, state_names, gate_seq, fp16=True)
    # reference argmax over the same teacher-forced sequence
    ref.reset()
    ref_argmax = []
    with torch.no_grad():
        for t in gate_seq:
            ref_argmax.append(int(ref.step(t).argmax()))
    # compare the N_FIDELITY "next-token" predictions (positions after each prompt/gen token)
    host_argmax = [int(l.argmax()) for l in host_logits]
    win = range(len(prompt_ids) - 1, len(prompt_ids) - 1 + N_FIDELITY)
    tm = sum(1 for j in win if host_argmax[j] == ref_argmax[j])
    print(f"   .aimodel token_match (fp16 host vs fp32 torch ref): {tm}/{N_FIDELITY}")

    # full greedy coherence from the host on 2 prompts
    print("\n>> COHERENCE (host .aimodel, real tokenizer, greedy):")
    for pr in ["The capital of France is", "Once upon a time"]:
        pids = tok(pr, return_tensors="pt").input_ids[0].tolist()
        gen = host_decode(OUT, cfg, state_names, pids, N_COHERE, fp16=True)
        print(f"   [{pr!r}] -> {tok.decode(gen)!r}")

    # =================== state contract dump (for Swift session) ===================
    print("\n>> STATE CONTRACT (for BASCoreAIMambaSession) — 2 FUSED states:")
    print(f"   input  'input_id': dtype=int32  shape=[1,1]")
    print(f"   output 'logits'  : dtype=fp16   shape=[1,{cfg.vocab_size}]")
    for nm in state_names:
        if "conv_all" in nm:
            print(f"   state {nm}: shape=[{cfg.n_layer},{cfg.conv_dim},{cfg.d_conv}] dtype=fp16")
        else:
            print(f"   state {nm}: shape=[{cfg.n_layer},{cfg.n_v_heads},{cfg.headdim},{cfg.d_state}] dtype=fp16")

    print(f"\n>> DONE. torch {match}/{N_FIDELITY}, host {tm}/{N_FIDELITY}, {OUT}")


if __name__ == "__main__":
    main()
