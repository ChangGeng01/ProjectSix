"""Tap-parity: TappedTarget.forward_with_taps must be BIT-EQUAL to the model's own forward
(the taps are observations, not interventions). Also records tap tensor stats for spec work."""
import sys, mlx.core as mx
sys.path.insert(0, "Tools/dflash_proto")
from dflash_drafter import TappedTarget
from mlx_lm import load
from mlx_lm.models.cache import make_prompt_cache

model, tok = load("mlx-community/Qwen3.5-4B-4bit")
msgs = [{"role": "user", "content": "How many prime numbers are there between 10 and 50?"}]
ids = tok.apply_chat_template(msgs, add_generation_prompt=True)
x = mx.array([ids])

# native forward (no cache, single shot)
native_logits = model(x)
mx.eval(native_logits)

tt = TappedTarget(model)
final, taps, logits = tt.forward_with_taps(x, None)
mx.eval(final, logits, *taps.values())

diff = mx.abs(native_logits - logits).max().item()
print(f"prompt_len={len(ids)} logits_max_abs_diff={diff}")
print(f"taps: {sorted(taps.keys())} shapes={ {k: tuple(v.shape) for k, v in taps.items()} }")
for k in sorted(taps):
    t = taps[k][0, -1].astype(mx.float32)
    print(f"  layer {k}: last-tok mean={t.mean().item():.4f} std={mx.sqrt(t.var()).item():.4f}")
assert diff == 0.0, "taps must not perturb the forward"
print("TAP PARITY: BIT-EQUAL ✓")
