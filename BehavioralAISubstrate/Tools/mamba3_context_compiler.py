"""Context Compiler — the closed-loop integration (浑然一体) of StateLake + resumable prefill + decode (Track G build).

Ties the pieces into ONE executable pipeline so a query flows: ROUTE (deepest cached prefix) → REUSE its state →
resume-PREFILL only the missing suffix → HANDOFF → DECODE — and the result equals a from-scratch prefill+decode. This is
the cross-cutting "one integrated system" the coverage scorecard scored ~35% (handoff-only); here it actually closes.

- compile(tokens, corpus): tile the corpus, prefill each tile RESUMING from the cumulative state (STEP 5), and store every
  cumulative-prefix boundary in StateLake with LINEAGE (each tile's state's parent = the prior tile) → every prefix reusable.
- serve(corpus, query, cont): route to the deepest valid cached prefix of the query, reuse it, prefill the suffix, decode.

Context packing (STEP 7, basic): fixed-tile segmentation along the corpus; the resumable scan stitches tiles exactly.
"""
from __future__ import annotations

import sys

import torch

sys.path.insert(0, "/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tools")
import mamba3_hybrid as HY
import mamba3_statelake as SL


def tokstr(ids) -> str:
    return ",".join(map(str, ids.tolist())) + ","                      # trailing ',' → token-prefix startswith is exact


def tile_ladder(n: int, ladder=(64,)):
    """Context packing: segment n tokens largest-tile-first into a multi-size ladder (few big tiles for the bulk, small
    for the tail) → fewer checkpoints for long docs, fine resume granularity at the end. ladder=(64,) = the fixed tile."""
    sizes, rem = [], n
    for t in sorted(ladder, reverse=True):
        while rem >= t:
            sizes.append(t); rem -= t
    if rem > 0:
        sizes.append(rem)
    return sizes


class ContextCompiler:
    def __init__(self, model, lake: SL.StateLake, bkey: str, layer_tags: list[str]):
        self.m, self.lake, self.bkey, self.tags = model, lake, bkey, layer_tags

    def compile(self, tokens, corpus: str, tile: int = 64, ladder=None):
        """Tile (via the tile-ladder packer) + resume-prefill the corpus; store every cumulative-prefix state with lineage.
        资料层 DEDUP: if a cumulative prefix was ALREADY compiled (same content+model — e.g. a shared system prompt across
        corpora), REUSE it instead of re-prefilling. `ladder` (e.g. (256,64,16)) = variable tile sizes; None = fixed `tile`.
        Returns (final state id, dedup_hits, tiles_total)."""
        sizes = tile_ladder(len(tokens), ladder if ladder else (tile,))
        state, parent, hits, total, start = None, None, 0, 0, 0
        for sz in sizes:
            chunk = tokens[start:start + sz]
            start += len(chunk)
            total += 1
            pfx = tokstr(tokens[:start])
            dup = self.lake.find_by_content(pfx, self.bkey)            # already compiled this exact prefix?
            if dup is not None:
                state, _ = self.lake.get(dup, "owner", self.bkey, self.tags)   # REUSE — skip prefill (dedup hit)
                parent, hits = dup, hits + 1
                continue
            _, state = self.m.prefill(chunk, init=state)               # RESUME from the running cumulative state
            parent = self.lake.put(state, start, self.bkey, corpus, pfx, self.tags, parent=parent, ttl_s=3600)
        return parent, hits, total

    def serve(self, corpus: str, query, cont):
        """ROUTE→REUSE→PREFILL-suffix→DECODE. Returns (argmax tokens, reused_prefix_len, prefilled_suffix_len, note)."""
        plan = self.lake.route(corpus, tokstr(query), self.bkey)
        if plan.state_id is not None:
            state, plen = self.lake.get(plan.state_id, "owner", self.bkey, self.tags)
        else:
            state, plen = None, 0
        suffix = query[plen:]
        if len(suffix) > 0:
            _, state = self.m.prefill(suffix, init=state)              # prefill ONLY the missing suffix
        with torch.no_grad():
            arg = self.m.run_ref(cont, init=state).argmax(-1)
        return arg, plen, len(suffix), plan.note


def _selftest() -> None:
    import shutil
    torch.manual_seed(0)
    V, L = 4096, 24
    m = HY.HybridM(V, L).float().eval()
    tags = ["mla" if i in m.mla_pos else "mamba" for i in range(L)]
    bkey = SL.binding_key(m, "int8", 256, True)
    root = "/tmp/ctxcompiler_test"; shutil.rmtree(root, ignore_errors=True)
    lake = SL.StateLake(root)
    cc = ContextCompiler(m, lake, bkey, tags)

    doc = torch.randint(0, V, (128,))                                  # the corpus
    query = torch.cat([doc[:96], torch.randint(0, V, (16,))])          # shares a 96-tok prefix, then a 16-tok question
    cont = torch.randint(0, V, (16,))                                  # the answer tokens to score

    print("Context Compiler self-test (浑然一体 closed loop, 24L hybrid, host):")
    final, hits, total = cc.compile(doc, "docA", tile=64)              # checkpoints at cum=64 and cum=128 (lineage chain)
    print(f"  compiled corpus (128 tok, tile=64) → {len(lake.lineage(final))} lineage checkpoints, final={final[:8]} (dedup {hits}/{total})")

    # 资料层 cross-corpus dedup: docB SHARES docA's first 64 tokens (a shared 'system prompt'); that tile must dedup-HIT
    docB = torch.cat([doc[:64], torch.randint(0, V, (64,))])
    _, hitsB, totalB = cc.compile(docB, "docB", tile=64)
    print(f"  (dedup) docB shares docA's 64-tok prefix → compile dedup {hitsB}/{totalB} (shared tile reused, not re-prefilled) "
          f"-> {'PASS' if hitsB == 1 else 'FAIL'}")

    arg, reused, prefilled, note = cc.serve("docA", query, cont)       # reuses the cum=64 checkpoint (deepest ≤96 prefix)
    with torch.no_grad():                                              # from-scratch ground truth
        _, sf = m.prefill(query)
        ref = m.run_ref(cont, init=sf).argmax(-1)
    agree = (arg == ref).float().mean().item()
    print(f"  served query (112 tok): reused {reused} cached tok, prefilled {prefilled} suffix tok  [{note[:38]}]")
    print(f"  decode(reuse-path) vs decode(from-scratch) argmax-agree = {agree:.0%}  -> {'PASS' if agree > 0.999 else 'FAIL'}")
    print(f"  work saved: {reused}/{len(query)} prefix tokens NOT re-prefilled ({100 * reused // len(query)}% of the prompt)")
    print("READ: PASS = the full loop ROUTE→REUSE→PREFILL-suffix→HANDOFF→DECODE reproduces from-scratch, reusing a cached prefix. "
          "浑然一体 is now an EXECUTABLE closed loop (host), not three stapled docs.")


if __name__ == "__main__":
    _selftest()
