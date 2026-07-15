# Fused decode kernel — design + measure-first plan (2026-06-30)

**Design only. No kernel was touched to produce this.** This exists so the decode-kernel red-line can be a
*decision* with a concrete, honest plan in front of the operator — not a default. It also **corrects an earlier
overstatement of mine**: the "~15–20%, clean win" figure is a *general* decode-kernel estimate; grounded in this
project's actual config it is **unverified and probably smaller** (see Headroom, below). Do NOT waive the red-line
on the strength of that number — waive it, if at all, only after the profile in Step 1 proves headroom exists.

## What a fused decode kernel is (and the batch-1 rationale)

At batch-1 single-token decode, per-token cost = (a) memory bandwidth reading all weights, (b) Metal **kernel-launch
overhead** across many small dispatches per layer, (c) materializing intermediate tensors between ops. (a) is
irreducible without quant. A fused kernel attacks (b)+(c): fuse a decode step's op-chain (norm → projections → mixer
→ out-proj → MLP gate/up/SiLU/down → residuals) into fewer dispatches with fewer intermediate round-trips. At
batch-1 the launch/intermediate fraction is larger than at batched serving, so fusion has more relative upside here
than in a datacenter — *if* it isn't already captured.

## Headroom — the honest caveat (why Step 1 is a profile, not a kernel)

Three facts make the real headroom uncertain and likely modest for THIS config:
1. **Qwen3.5-4B is a GDN-hybrid** (`fullAttentionInterval:4`): ¾ layers are gated-delta linear attention, ¼ full
   attention. The mixer is a **GDN state-scan**, already a specialized kernel — not a vanilla attention you can
   trivially out-fuse. Any fused kernel must handle *both* layer types.
2. **MLX is mature and has `compile()`** (graph-level fusion). Much of the elementwise/intermediate fusion (b)+(c)
   may already be captured by the vendored runtime; the marginal win of a hand-fused kernel over it is unknown.
3. **Production decode runs through vendored MLX**, not BAS's own Metal substrate (`BASMetalFlashAttentionDispatcher`
   / `BASMetalSSMScanDispatcher` exist but are off the hot path — P8). So realizing a fused kernel means one of two
   *large* routes (below), each red-line-adjacent.

⇒ The general ~15–20% could be largely pre-captured by MLX. **Unverified. Measure before believing it.**

## Step 1 — PROFILE (cheap, observation-only, NEEDS NO WAIVER). Do this first.

On the **A19** (Mac data is not representative), instrument the Qwen3.5-4B decode step and record:
- Metal **dispatch count per token** (how many kernels per layer × layers) — the fusible surface.
- **Time breakdown**: matmul (bandwidth-bound) vs GDN-scan vs full-attention vs elementwise/launch overhead.
- **GPU occupancy / memory-bandwidth utilization** during decode (are we bandwidth-bound already? if occupancy is
  high and bandwidth saturated, fusion buys little — the win is quant, not fusion).
- Compare with vs without `mx.compile` on the decode graph (does compile already fuse it?).

**Decision gate:** if launch/intermediate overhead is <~5% of decode time (i.e. decode is already bandwidth-bound
and/or MLX-compile-fused), the fused kernel is NOT the lever → stop, the real lever is quant (bandwidth) and the
red-line stays. Only if there is a real, sizable non-bandwidth overhead does Step 2 (and the waiver question) arise.

## Step 2 — IF headroom is real: the two routes (both need the waiver)

- **Route A — fuse within vendored MLX** (touches the vendored decode path = red-line): add a fused decode-block
  Metal kernel for the GDN layer + one for the full-attention layer. Smaller blast radius per kernel, but it's the
  vendored hot path.
- **Route B — re-plumb decode onto BAS's own Metal substrate** (`BASMetalSSMScanDispatcher` for GDN,
  `BASMetalFlashAttentionDispatcher` for full attention): a major re-plumbing that makes BAS kernels the decode path
  instead of MLX. Larger, but keeps changes out of the vendored tree.

Prototype **one** fused block first (the GDN layer — ¾ of the model), measure it in isolation, before touching the
rest. Do not fuse the whole model up front.

## Step 3 — BYTE-PARITY SAFETY GATE (the red-line's actual concern)

The decode red-line is about not silently changing model outputs / determinism. The correct safety bar for a
swapped kernel is **token-identity**, not bit-identity of intermediates (fp16 accumulation order will differ; that's
fine as long as the argmax doesn't flip). Protocol:
- Run a large prompt set (≥500 diverse prompts, greedy/temp-0) through **both** the reference MLX path and the fused
  kernel; assert the **greedy token sequences are identical**.
- Measure the **argmax-flip rate** on near-tied logits (two top tokens within ~1 fp16 ulp). Report it explicitly.
- **Ship gate:** token-identical on 100% of the set → safe to swap. Any flips → the substrate must decide whether
  its determinism contract tolerates rare near-tie flips (a sovereign/byte-parity substrate likely does **not** →
  then the kernel must match reduction order closely enough to eliminate them, or it's rejected). This is separate
  from and does NOT touch the Swift↔Rust sovereign-verdict byte-parity (that red-line is untouched throughout).

## Recommendation

**Do Step 1 (the profile) first — it needs no waiver and it decides everything.** If MLX has already captured the
fusion (likely, given its maturity + `compile` + the GDN-specialized kernels), the fused kernel is not the lever and
the red-line correctly stays closed; the residual throughput lever is then mixed-precision quant (bandwidth), per
`THROUGHPUT_CAMPAIGN_2026-06.md`. Only a profile showing real, non-bandwidth overhead justifies opening the red-line
— and even then, behind the token-identity parity gate above. Design delivered; **no kernel touched; the waiver is
yours to grant only if the profile earns it.**
