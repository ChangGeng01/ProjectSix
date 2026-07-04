"""M1 Gate-a — z-lab OFFICIAL MLX DFlash on our stack (Mac): Qwen3.5-4B-4bit target +
z-lab/Qwen3.5-4B-DFlash drafter, temp 0, chat-templated prompts.

Uses z-lab's dflash/model_mlx.py verbatim (scratchpad copy) — reference-grade fidelity, no
reconstruction risk. Local load_draft variant flattens the transformers-5.7 config nesting
(dflash_config.block_size / rope_parameters.rope_theta → top level, the gotcha the repo's own
loader trips on with this checkpoint).

Output per prompt: mean accept-len per cycle, dflash tok/s, plain tok/s, ratio.
"""
import json, sys, time
from pathlib import Path

SCRATCH = "/private/tmp/claude-501/-Users-changgeng-Project-Project06-Project06/e230e4e0-d99f-4df6-8e9b-76b5529d5140/scratchpad"
sys.path.insert(0, SCRATCH)
import mlx.core as mx
import model_mlx as Z
from mlx_lm import load
from mlx_lm.generate import stream_generate as plain_stream

DRAFT_DIR = Path("/tmp/gdn_coreai/dflash_draft")

PROMPTS = [
    "How many prime numbers are there between 10 and 50? Think step by step.",
    "Describe a quiet morning in a mountain village.",
    "What is 23 multiplied by 17? Show your reasoning.",
    "Explain what a tide pool is to a curious child.",
]


def load_draft_local(path: Path) -> "Z.DFlashDraftModel":
    cfg = json.loads((path / "config.json").read_text())
    # flatten transformers-5.7 nesting for the repo's DFlashConfig
    dfc = cfg.get("dflash_config", {})
    cfg.setdefault("block_size", dfc.get("block_size", 16))
    if "rope_theta" not in cfg:
        cfg["rope_theta"] = cfg.get("rope_parameters", {}).get("rope_theta", 1e7)
    layer_types = tuple(cfg.get("layer_types") or ["full_attention"] * cfg["num_hidden_layers"])
    config = Z.DFlashConfig(
        hidden_size=cfg["hidden_size"],
        num_hidden_layers=cfg["num_hidden_layers"],
        num_attention_heads=cfg["num_attention_heads"],
        num_key_value_heads=cfg["num_key_value_heads"],
        head_dim=cfg["head_dim"],
        intermediate_size=cfg["intermediate_size"],
        vocab_size=cfg["vocab_size"],
        rms_norm_eps=cfg["rms_norm_eps"],
        rope_theta=cfg["rope_theta"],
        max_position_embeddings=cfg["max_position_embeddings"],
        block_size=cfg["block_size"],
        target_layer_ids=tuple(dfc["target_layer_ids"]),
        num_target_layers=cfg["num_target_layers"],
        mask_token_id=dfc["mask_token_id"],
        rope_scaling=cfg.get("rope_scaling"),
        layer_types=layer_types,
        sliding_window=cfg.get("sliding_window"),
        final_logit_softcapping=cfg.get("final_logit_softcapping"),
    )
    weights = {k: v for f in path.glob("*.safetensors") for k, v in mx.load(str(f)).items()}
    m = Z.DFlashDraftModel(config)
    m.load_weights(list(weights.items()))
    return m


def main():
    import os
    import mlx.nn as nn
    model, tok = load("mlx-community/Qwen3.5-4B-4bit")
    draft = load_draft_local(DRAFT_DIR)
    if os.environ.get("DFLASH_Q4") == "1":
        # Quantize the drafter linears to 4-bit/g64 (the production MTP-head recipe):
        # f (draft cost per cycle) drops ~4x; the question is what it costs in accept-len.
        nn.quantize(draft, group_size=64, bits=4,
                    class_predicate=lambda _, m: isinstance(m, nn.Linear))
        mx.eval(draft.parameters())
        print("drafter QUANTIZED 4-bit/g64")
    print("loaded target + drafter")

    for q in PROMPTS:
        ids = tok.apply_chat_template(
            [{"role": "user", "content": q}], add_generation_prompt=True)

        # plain baseline
        t0 = time.time()
        n_plain = 0
        for r in plain_stream(model, tok, prompt=ids, max_tokens=256):
            n_plain += 1
        plain_s = time.time() - t0
        plain_tps = n_plain / plain_s

        # dflash
        accepts, n_df = [], 0
        t0 = time.time()
        last = None
        for r in Z.stream_generate(model, draft, tok, mx.array(ids), max_tokens=256,
                                   temperature=0.0):
            if r.tokens:
                accepts.append(r.accepted)
                n_df += len(r.tokens)
            last = r
        df_s = time.time() - t0
        df_tps = (last.generation_tps if last else 0)
        mean_acc = sum(accepts) / max(1, len(accepts))
        print(f"[gate-a] {q[:40]:40s} accept-len={mean_acc:.2f} cycles={len(accepts)} "
              f"dflash={df_tps:.1f} tok/s plain={plain_tps:.1f} tok/s ratio={df_tps/plain_tps:.2f}x")


if __name__ == "__main__":
    main()
