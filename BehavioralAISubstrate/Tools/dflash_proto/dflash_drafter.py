"""M1 DFlash — Python-MLX prototype of the z-lab Qwen3.5-4B-DFlash drafter (Gate-a: Mac α).

Checkpoint facts (verified from /tmp/gdn_coreai/dflash_draft):
  • 6-layer Qwen3-attention stack (5 sliding_attention@4096 + 1 full_attention), hidden 2560,
    32 q-heads / 8 kv-heads × head_dim 128, per-head q/k RMSNorm, MLP 9216, rope_theta 1e7.
  • fc.weight [2560, 20480]: concat of EIGHT target-layer hidden states (2560×8) → 2560.
  • hidden_norm [2560] + final norm [2560].
  • NO embedding / NO lm_head in the checkpoint — tied to the TARGET's embed_tokens (input AND head).
  • dflash_config: block_size 16, mask_token_id 248077, target_layer_ids [1,5,9,13,17,21,25,29].

The block-construction / position semantics are filled in from the z-lab reference (see
dflash_spec notes in the campaign doc); this module holds the spec-independent parts.
"""
import json
import mlx.core as mx
import mlx.nn as nn

DRAFT_DIR = "/tmp/gdn_coreai/dflash_draft"


class DFlashAttention(nn.Module):
    def __init__(self, hidden=2560, n_heads=32, n_kv=8, head_dim=128, rope_theta=1e7):
        super().__init__()
        self.n_heads, self.n_kv, self.head_dim = n_heads, n_kv, head_dim
        self.q_proj = nn.Linear(hidden, n_heads * head_dim, bias=False)
        self.k_proj = nn.Linear(hidden, n_kv * head_dim, bias=False)
        self.v_proj = nn.Linear(hidden, n_kv * head_dim, bias=False)
        self.o_proj = nn.Linear(n_heads * head_dim, hidden, bias=False)
        self.q_norm = nn.RMSNorm(head_dim, eps=1e-6)
        self.k_norm = nn.RMSNorm(head_dim, eps=1e-6)
        self.rope = nn.RoPE(head_dim, traditional=False, base=rope_theta)

    def __call__(self, x, mask=None, positions_offset=0):
        B, L, _ = x.shape
        q = self.q_proj(x).reshape(B, L, self.n_heads, self.head_dim)
        k = self.k_proj(x).reshape(B, L, self.n_kv, self.head_dim)
        v = self.v_proj(x).reshape(B, L, self.n_kv, self.head_dim)
        q = self.q_norm(q).transpose(0, 2, 1, 3)
        k = self.k_norm(k).transpose(0, 2, 1, 3)
        v = v.transpose(0, 2, 1, 3)
        q = self.rope(q, offset=positions_offset)
        k = self.rope(k, offset=positions_offset)
        out = mx.fast.scaled_dot_product_attention(
            q, k, v, scale=self.head_dim ** -0.5, mask=mask)
        out = out.transpose(0, 2, 1, 3).reshape(B, L, -1)
        return self.o_proj(out)


class DFlashMLP(nn.Module):
    def __init__(self, hidden=2560, inter=9216):
        super().__init__()
        self.gate_proj = nn.Linear(hidden, inter, bias=False)
        self.up_proj = nn.Linear(hidden, inter, bias=False)
        self.down_proj = nn.Linear(inter, hidden, bias=False)

    def __call__(self, x):
        return self.down_proj(nn.silu(self.gate_proj(x)) * self.up_proj(x))


class DFlashLayer(nn.Module):
    def __init__(self):
        super().__init__()
        self.self_attn = DFlashAttention()
        self.mlp = DFlashMLP()
        self.input_layernorm = nn.RMSNorm(2560, eps=1e-6)
        self.post_attention_layernorm = nn.RMSNorm(2560, eps=1e-6)

    def __call__(self, x, mask=None, positions_offset=0):
        x = x + self.self_attn(self.input_layernorm(x), mask, positions_offset)
        return x + self.mlp(self.post_attention_layernorm(x))


class DFlashDrafter(nn.Module):
    """Spec-independent core: fc feature-fusion + 6-layer stack + final norm.
    Embedding/head come from the TARGET model (tied); sequence construction lives in the loop."""

    def __init__(self):
        super().__init__()
        self.fc = nn.Linear(2560 * 8, 2560, bias=False)
        self.hidden_norm = nn.RMSNorm(2560, eps=1e-6)
        self.layers = [DFlashLayer() for _ in range(6)]
        self.norm = nn.RMSNorm(2560, eps=1e-6)

    def fuse_target_features(self, feats):
        """feats: [B, L, 8*2560] concat of the 8 tapped target layers → [B, L, 2560]."""
        return self.fc(self.hidden_norm(feats.reshape(*feats.shape[:-1], 8, 2560))
                       .reshape(*feats.shape))

    def trunk(self, x, mask=None, positions_offset=0):
        for layer in self.layers:
            x = layer(x, mask, positions_offset)
        return self.norm(x)


def load_drafter(path=DRAFT_DIR):
    w = mx.load(f"{path}/model.safetensors")
    d = DFlashDrafter()
    params = {}
    params["fc"] = {"weight": w["fc.weight"]}
    params["hidden_norm"] = {"weight": w["hidden_norm.weight"]}
    params["norm"] = {"weight": w["norm.weight"]}
    layers = []
    for i in range(6):
        p = f"layers.{i}."
        layers.append({
            "self_attn": {
                "q_proj": {"weight": w[p + "self_attn.q_proj.weight"]},
                "k_proj": {"weight": w[p + "self_attn.k_proj.weight"]},
                "v_proj": {"weight": w[p + "self_attn.v_proj.weight"]},
                "o_proj": {"weight": w[p + "self_attn.o_proj.weight"]},
                "q_norm": {"weight": w[p + "self_attn.q_norm.weight"]},
                "k_norm": {"weight": w[p + "self_attn.k_norm.weight"]},
            },
            "mlp": {
                "gate_proj": {"weight": w[p + "mlp.gate_proj.weight"]},
                "up_proj": {"weight": w[p + "mlp.up_proj.weight"]},
                "down_proj": {"weight": w[p + "mlp.down_proj.weight"]},
            },
            "input_layernorm": {"weight": w[p + "input_layernorm.weight"]},
            "post_attention_layernorm": {"weight": w[p + "post_attention_layernorm.weight"]},
        })
    params["layers"] = layers
    d.update(params)
    mx.eval(d.parameters())
    return d


class TappedTarget:
    """The target (mlx_lm Qwen3.5-4B) with hidden-state taps after the configured layer ids."""

    def __init__(self, model, layer_ids=(1, 5, 9, 13, 17, 21, 25, 29)):
        self.model = model
        # mlx_lm qwen3_5 layout: Model.language_model (TextModel) . model (Qwen3_5TextModel)
        self.text = model.language_model
        self.inner = self.text.model
        self.layer_ids = set(layer_ids)

    def forward_with_taps(self, inputs, cache):
        """Mirrors Qwen3_5TextModel.__call__ with per-layer capture. Returns (final_hidden, taps
        dict layer_id → hidden [B, L, 2560], logits)."""
        import mlx_lm.models.qwen3_5 as q35
        tm = self.inner
        h = tm.embed_tokens(inputs)
        if cache is None:
            cache = [None] * len(tm.layers)
        fa_mask = q35.create_attention_mask(h, cache[tm.fa_idx])
        ssm_mask = q35.create_ssm_mask(h, cache[tm.ssm_idx])
        taps = {}
        for i, (layer, c) in enumerate(zip(tm.layers, cache)):
            mask = ssm_mask if layer.is_linear else fa_mask
            h = layer(h, mask=mask, cache=c)
            if i in self.layer_ids:
                taps[i] = h
        final = tm.norm(h)
        logits = tm.embed_tokens.as_linear(final) if self.text.args.tie_word_embeddings \
            else self.text.lm_head(final)
        return final, taps, logits


if __name__ == "__main__":
    d = load_drafter()
    from mlx.utils import tree_flatten
    n = sum(v.size for _, v in tree_flatten(d.parameters()))
    print(f"drafter loaded: {n/1e6:.1f}M params")
    x = mx.random.normal((1, 4, 2560)).astype(mx.bfloat16)
    y = d.trunk(x)
    mx.eval(y)
    print("trunk forward ok:", y.shape, y.dtype)
    f = mx.random.normal((1, 4, 2560 * 8)).astype(mx.bfloat16)
    z = d.fuse_target_features(f)
    mx.eval(z)
    print("fc fusion ok:", z.shape)
