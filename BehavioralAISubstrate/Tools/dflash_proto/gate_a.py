"""M1 Gate-a — teacher-forced block acceptance of the DFlash drafter on Mac (Python MLX).

PROVISIONAL sequence construction (reconstructed from weight shapes; pending z-lab spec confirm):
  drafter_input[0..P-1] = fc( concat_8( hidden_norm(target tap layers) ) )   # context features
  drafter_input[P..P+15] = target.embed(mask_token=248077)                    # the block slots
  → drafter trunk (causal, RoPE positions 0..P+15) → last 16 hiddens
  → target embed-as-linear head → argmax = 16 draft tokens (ONE forward, one-step).

TEACHER-FORCED protocol (accept-len, LMSYS reference 3.0-4.2 @temp0):
  gt = target's own greedy continuation; ONE tapped batch forward over prompt+gt gives every
  position's features (causal ⇒ identical to decode-time). At each block start j: draft 16 from
  features[:P], accept-len = longest prefix match vs gt[j:j+16]. EPISTEMICS: only a POSITIVE
  result is informative — a wrong provisional construction fakes LOW α, never high.
"""
import sys, time
import mlx.core as mx

sys.path.insert(0, "Tools/dflash_proto")
from dflash_drafter import DFlashDrafter, TappedTarget, load_drafter
from mlx_lm import load
from mlx_lm.models.cache import make_prompt_cache

MASK_ID = 248077
BLOCK = 16
LAYERS = (1, 5, 9, 13, 17, 21, 25, 29)

PROMPTS = [
    "How many prime numbers are there between 10 and 50? Think step by step.",
    "Describe a quiet morning in a mountain village.",
    "What is 23 multiplied by 17? Show your reasoning.",
    "Explain what a tide pool is to a curious child.",
]


def greedy_continuation(model, ids, n):
    cache = make_prompt_cache(model)
    x = mx.array([ids])
    logits = model(x, cache=cache)
    out = []
    tok = mx.argmax(logits[0, -1]).item()
    out.append(tok)
    for _ in range(n - 1):
        logits = model(mx.array([[tok]]), cache=cache)
        tok = mx.argmax(logits[0, -1]).item()
        out.append(tok)
    return out


def draft_block(drafter, embed, taps_cat, P):
    """PROVISIONAL: context features [1,P,8*2560] + 16 mask embeds → 16 draft ids."""
    ctx = drafter.fuse_target_features(taps_cat[:, :P])            # [1,P,2560]
    mask_emb = embed(mx.array([[MASK_ID] * BLOCK]))                # [1,16,2560]
    x = mx.concatenate([ctx, mask_emb], axis=1)
    h = drafter.trunk(x, mask="causal")
    block_h = h[:, -BLOCK:]
    logits = embed.as_linear(block_h)
    return mx.argmax(logits, axis=-1)[0]                           # [16]


def main():
    model, tok = load("mlx-community/Qwen3.5-4B-4bit")
    drafter = load_drafter()
    tt = TappedTarget(model, LAYERS)
    embed = tt.inner.embed_tokens
    accepts = []
    for q in PROMPTS:
        ids = tok.apply_chat_template(
            [{"role": "user", "content": q}], add_generation_prompt=True)
        gt = greedy_continuation(model, ids, 128)
        full = list(ids) + gt
        _, taps, _ = tt.forward_with_taps(mx.array([full]), None)
        taps_cat = mx.concatenate([taps[i] for i in LAYERS], axis=-1)   # [1,L,8*2560]
        mx.eval(taps_cat)
        pa = []
        t0 = time.time()
        for j in range(0, 128 - BLOCK, BLOCK):
            P = len(ids) + j
            ds = draft_block(drafter, embed, taps_cat, P)
            mx.eval(ds)
            gtb = gt[j:j + BLOCK]
            acc = 0
            for a, b in zip(ds.tolist(), gtb):
                if a == b:
                    acc += 1
                else:
                    break
            pa.append(acc)
        accepts.append(sum(pa) / len(pa))
        print(f"[gate-a] {q[:44]:44s} accept-len={accepts[-1]:.2f} blocks={pa} ({time.time()-t0:.1f}s)")
    print(f"[gate-a] MEAN accept-len={sum(accepts)/len(accepts):.2f} (LMSYS ref 3.0-4.2; provisional construction — only a HIGH value is informative)")


if __name__ == "__main__":
    main()
