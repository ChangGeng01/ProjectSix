#!/usr/bin/env python3
"""B2 — REAL Llama-3.2-1B-Instruct → stateful Core ML draft decoder (the ANE half of the ANE∥GPU hybrid).

The A19 proved (Track B2-GO) that a stateful KV Core ML decoder plans 100% onto the A19 ANE. This builds the
REAL draft: load Llama-3.2-1B weights (same Llama-3.2 tokenizer as the 3B target → draft token ids are valid
target ids, the requirement for greedy spec-decode), into a stateful module whose per-layer KV caches are
iOS18 `ct.StateType`s, written by the fixed-window static-slice pattern that A19-ANE-places.

ANE-friendliness + exact fidelity: RoPE cos/sin (exact llama3 scaling) and the write-onehot + additive attn
mask are HOST-computed and passed as INPUTS — no dynamic RoPE/compare in-graph. GQA (8 KV heads → 32 query
heads) via static repeat_interleave; tied embeddings (lm_head = embed_tokens). fp16.

Pipeline: load HF model → build StatefulLlamaDraft + copy weights → TORCH fidelity check (greedy decode vs HF,
token-identical) → convert to Core ML mlprogram stateful fp16 → save. Conversion/fidelity must BOTH pass before
the Swift hybrid loop is worth building (亏的不要).

Run:  /tmp/cml312/bin/python3 Tools/llama_draft_to_coreml.py [hf_model_dir_or_id]
Out:  /tmp/draft/LlamaDraft1B_fp16.mlpackage   (+ prints fidelity verdict)
"""
import os
import sys

import numpy as np
import torch
import torch.nn as nn
import coremltools as ct
from transformers import AutoModelForCausalLM, AutoTokenizer

MODEL = sys.argv[1] if len(sys.argv) > 1 else "unsloth/Llama-3.2-1B-Instruct"
# Supply-chain (audit fix): pin an immutable revision so the weights that become the on-device ANE draft are
# reproducible and not whatever a mutable mirror serves later. For production prefer the canonical gated source
# (meta-llama/Llama-3.2-1B-Instruct) with an explicit HF token. Override revision via argv[2].
REVISION = (sys.argv[2] if len(sys.argv) > 2
            else "5a8abab4a5d6f164389b1079fb721cfab8d7126c" if MODEL == "unsloth/Llama-3.2-1B-Instruct"
            else None)
# MAX_SEQ is a HARD cap on the KV window. The host driver MUST keep position < MAX_SEQ (it indexes write_onehot
# and attn_bias of this length); past it the draft has no eviction and would corrupt/crash. For generations
# longer than MAX_SEQ a sliding-window eviction is required (not implemented — drafts are short-horizon).
MAX_SEQ = 512
OUT_DIR = "/tmp/draft"
OUT = f"{OUT_DIR}/LlamaDraft1B_fp16.mlpackage"


def rotate_half(x: torch.Tensor, half: int) -> torch.Tensor:
    # `half` is a Python int constant (head_dim//2) — using x.shape[-1] here traces to a dynamic size op that
    # coremltools tries to const-fold via an int() cast on a non-scalar → "only 0-dimensional arrays" error.
    return torch.cat((-x[..., half:], x[..., :half]), dim=-1)


class StatefulLlamaDraft(nn.Module):
    """Llama-3.2-1B decoder with iOS18 stateful KV. forward(input_id, rope_cos, rope_sin, write_onehot,
    attn_bias) -> logits[1, VOCAB]. All RoPE/mask values are host-supplied inputs (exact, ANE-friendly)."""

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
        for li in range(self.n_layers):
            self.register_buffer(f"k_cache_{li}", torch.zeros(1, self.n_kv, MAX_SEQ, self.head_dim))
            self.register_buffer(f"v_cache_{li}", torch.zeros(1, self.n_kv, MAX_SEQ, self.head_dim))

    def _rms(self, x: torch.Tensor, w: torch.Tensor) -> torch.Tensor:
        return x * torch.rsqrt(x.pow(2).mean(-1, keepdim=True) + self.eps) * w

    def forward(self, input_id, rope_cos, rope_sin, write_onehot, attn_bias):
        oh = write_onehot.view(1, 1, MAX_SEQ, 1)
        keep = 1.0 - oh
        bias = attn_bias.view(1, 1, 1, MAX_SEQ)
        cos = rope_cos.view(1, 1, 1, self.head_dim)
        sin = rope_sin.view(1, 1, 1, self.head_dim)
        x = self.embed(input_id)   # [1,1,H]
        for li in range(self.n_layers):
            h = self._rms(x, self.in_norm[li])
            q = self.q[li](h).view(1, 1, self.n_heads, self.head_dim).transpose(1, 2)   # [1,nh,1,D]
            k = self.k[li](h).view(1, 1, self.n_kv, self.head_dim).transpose(1, 2)      # [1,nkv,1,D]
            v = self.v[li](h).view(1, 1, self.n_kv, self.head_dim).transpose(1, 2)
            half = self.head_dim // 2
            q = q * cos + rotate_half(q, half) * sin
            k = k * cos + rotate_half(k, half) * sin
            kc = getattr(self, f"k_cache_{li}") * keep + k * oh    # [1,nkv,MAX_SEQ,D] one-hot write
            vc = getattr(self, f"v_cache_{li}") * keep + v * oh
            getattr(self, f"k_cache_{li}")[:, :, :, :] = kc        # static-slice state write-back
            getattr(self, f"v_cache_{li}")[:, :, :, :] = vc
            kr = kc.repeat_interleave(self.rep, dim=1)             # GQA expand nkv→nh
            vr = vc.repeat_interleave(self.rep, dim=1)
            scores = (q @ kr.transpose(-1, -2)) * self.scale + bias   # [1,nh,1,MAX_SEQ]
            attn = torch.softmax(scores, dim=-1)
            out = (attn @ vr).transpose(1, 2).reshape(1, 1, self.n_heads * self.head_dim)
            x = x + self.o[li](out)
            h2 = self._rms(x, self.post_norm[li])
            x = x + self.down[li](torch.nn.functional.silu(self.gate[li](h2)) * self.up[li](h2))
        x = self._rms(x, self.final_norm)
        return x @ self.embed.weight.t()    # tied lm_head → [1,1,VOCAB]


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


def main() -> None:
    os.makedirs(OUT_DIR, exist_ok=True)
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
        cos, sin = rotary(dummy, pid)     # [1,1,head_dim]
        return cos[0, 0], sin[0, 0]

    # ---- TORCH fidelity: greedy decode vs HF, token-identical ----
    prompt = "The capital of France is"
    ids = tok(prompt, return_tensors="pt").input_ids
    n_new = 24
    with torch.no_grad():
        hf_out = hf.generate(ids, max_new_tokens=n_new, do_sample=False, use_cache=True,
                             pad_token_id=tok.eos_token_id)
    hf_new = hf_out[0, ids.shape[1]:].tolist()

    # Draft stateful greedy loop: prefill the prompt, then decode.
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
    print(f">> FIDELITY hf_new={hf_new}")
    print(f">> FIDELITY draft_new={draft_new}")
    print(f">> FIDELITY token_match={match}/{n_new}  text={tok.decode(draft_new)!r}")
    if match < n_new:
        print(">> FIDELITY FAIL — not token-identical; NOT converting (fix the module first).")
        sys.exit(2)
    print(">> FIDELITY PASS — token-identical to HF greedy. Converting to Core ML…")

    # ---- Convert stateful fp16 ----
    c0, s0 = cos_sin(0)
    sample = (torch.tensor([[ids[0, 0].item()]], dtype=torch.long), c0, s0,
              torch.zeros(MAX_SEQ), torch.cat([torch.zeros(1), torch.full((MAX_SEQ - 1,), -1e4)]))
    with torch.no_grad():
        traced = torch.jit.trace(draft, sample)
    states = []
    for li in range(draft.n_layers):
        states.append(ct.StateType(wrapped_type=ct.TensorType(shape=(1, draft.n_kv, MAX_SEQ, draft.head_dim)), name=f"k_cache_{li}"))
        states.append(ct.StateType(wrapped_type=ct.TensorType(shape=(1, draft.n_kv, MAX_SEQ, draft.head_dim)), name=f"v_cache_{li}"))
    ml = ct.convert(
        traced,
        inputs=[
            ct.TensorType(name="input_id", shape=(1, 1), dtype=np.int32),
            ct.TensorType(name="rope_cos", shape=(draft.head_dim,), dtype=np.float32),
            ct.TensorType(name="rope_sin", shape=(draft.head_dim,), dtype=np.float32),
            ct.TensorType(name="write_onehot", shape=(MAX_SEQ,), dtype=np.float32),
            ct.TensorType(name="attn_bias", shape=(MAX_SEQ,), dtype=np.float32),
        ],
        outputs=[ct.TensorType(name="logits", dtype=np.float32)],
        states=states,
        minimum_deployment_target=ct.target.iOS18,
        compute_units=ct.ComputeUnit.ALL,
        compute_precision=ct.precision.FLOAT16,
        convert_to="mlprogram",
    )
    ml.save(OUT)
    print(f">> SAVED {OUT}")

    # ---- fp16 FIDELITY re-check (audit fix): the gate above ran in fp32, but the SHIPPED artifact is fp16. Run
    # the SAME greedy loop through the actual fp16 Core ML model (stateful predict) and report its token-match —
    # never certify fidelity for a model we didn't run. fp16 rounding/overflow can diverge from fp32. ----
    try:
        cm = ct.models.MLModel(OUT)
        cstate = cm.make_state()

        def cm_step(tid: int, pos: int):
            c, s = cos_sin(pos)
            oh = np.zeros(MAX_SEQ, dtype=np.float32); oh[pos] = 1.0
            bias = np.zeros(MAX_SEQ, dtype=np.float32); bias[pos + 1:] = -1e4
            out = cm.predict({
                "input_id": np.array([[tid]], dtype=np.int32),
                "rope_cos": c.numpy().astype(np.float32),
                "rope_sin": s.numpy().astype(np.float32),
                "write_onehot": oh, "attn_bias": bias,
            }, state=cstate)
            return np.asarray(out["logits"]).reshape(-1)

        p = 0
        for t in ids[0].tolist():
            lg16 = cm_step(t, p); p += 1
        cm_new = []
        nxt = int(lg16.argmax())
        for _ in range(n_new):
            cm_new.append(nxt); lg16 = cm_step(nxt, p); p += 1; nxt = int(lg16.argmax())
        cm_match = sum(1 for a, b in zip(hf_new, cm_new) if a == b)
        print(f">> FP16 FIDELITY cm_new={cm_new}")
        print(f">> FP16 FIDELITY token_match={cm_match}/{n_new}  text={tok.decode(cm_new)!r}")
        if cm_match < n_new:
            print(">> FP16 FIDELITY WARNING — the fp16 Core ML model DIVERGES from fp32/HF greedy; acceptance "
                  "as a draft will be lower (byte-identity still holds — the TARGET verify guarantees output).")
        else:
            print(">> FP16 FIDELITY PASS — the shipped fp16 model is token-identical too.")
    except Exception as e:
        print(f">> FP16 FIDELITY SKIPPED (stateful Core ML predict unavailable here: {e})")


if __name__ == "__main__":
    main()
