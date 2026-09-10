"""Regression pins for the hybrid Mamba-3 + MLA backbone (Tools/mamba3_hybrid.py, Tools/mamba3_mla.py).

These tests freeze the audited invariants that keep the paid cloud distill run safe:
  * HybridM structure / MLA placement (the 4-of-24 spacing, dropped when layers<=position)
  * the heterogeneous DUET handoff (per-layer ("mamba", 4-tuple) | ("mla", latent-cache))
  * PREFIX STATE REUSE: prefill(prompt) -> resume the suffix == decode the whole sequence
  * free-running greedy decode determinism + eos / max_new stopping
  * MLABlock cached single-token decode == causal-prefix forward_seq

Tight numerical claims use fp64 (model.double()). CPU-only, no Granite / coreai.
"""
from __future__ import annotations

import pytest
import torch

import mamba3_hybrid as HY
import mamba3_mla as MLA
import mamba3_trainable as MT


# ----------------------------------------------------------------------------
# (1)/(2) HybridM structure + MLA placement
# ----------------------------------------------------------------------------
def test_mla_pos_at_8_is_singleton_6(tiny_hybrid):
    """L=8 -> only position 6 of MLA_POSITIONS=(6,12,18,23) is < 8."""
    assert tiny_hybrid.mla_pos == {6}


def test_mla_pos_full_24_is_all_four():
    """The deploy backbone L=24 places MLA at every audited position."""
    m = HY.HybridM(96, 24)
    assert m.mla_pos == {6, 12, 18, 23}


def test_mla_pos_at_4_is_empty_all_dropped():
    """L=4: every MLA position (>=6) is dropped -> a pure-Mamba model."""
    m = HY.HybridM(96, 4)
    assert m.mla_pos == set()
    assert all(isinstance(l, MT.Lyr) for l in m.layers)


def test_mla_pos_boundary_layers_6_keeps_none_7_keeps_six():
    """Boundary: position 6 is included iff layers > 6 (strict `< layers`)."""
    assert HY.HybridM(96, 6).mla_pos == set()
    assert HY.HybridM(96, 7).mla_pos == {6}


def test_layer_types_match_mla_pos(tiny_hybrid):
    """MLABlock exactly at mla_pos, MT.Lyr everywhere else."""
    for i, lyr in enumerate(tiny_hybrid.layers):
        if i in tiny_hybrid.mla_pos:
            assert isinstance(lyr, MLA.MLABlock), f"layer {i} should be MLA"
        else:
            assert isinstance(lyr, MT.Lyr), f"layer {i} should be Mamba"


def test_layer_count_matches_request():
    for L in (4, 7, 8, 13, 24):
        assert len(HY.HybridM(96, L).layers) == L


def test_custom_mla_positions_filtered_by_layers():
    """A caller-supplied mla_positions is still filtered by `< layers`."""
    m = HY.HybridM(96, 8, mla_positions=(1, 3, 9, 20))
    assert m.mla_pos == {1, 3}
    assert isinstance(m.layers[1], MLA.MLABlock)
    assert isinstance(m.layers[3], MLA.MLABlock)
    assert isinstance(m.layers[0], MT.Lyr)


def test_is_mla_helper_agrees_with_mla_pos(tiny_hybrid):
    for i in range(len(tiny_hybrid.layers)):
        assert tiny_hybrid._is_mla(i) == (i in tiny_hybrid.mla_pos)


# ----------------------------------------------------------------------------
# (5) _zero_state: heterogeneous handoff with correct per-layer shapes
# ----------------------------------------------------------------------------
def test_zero_state_length_and_tags(tiny_hybrid):
    zs = tiny_hybrid._zero_state()
    assert len(zs) == len(tiny_hybrid.layers)
    for i, (tag, _s) in enumerate(zs):
        assert tag == ("mla" if i in tiny_hybrid.mla_pos else "mamba")


def test_zero_state_mla_entry_is_none(tiny_hybrid):
    zs = tiny_hybrid._zero_state()
    for i in tiny_hybrid.mla_pos:
        assert zs[i] == ("mla", None)


def test_zero_state_mamba_4tuple_shapes(tiny_hybrid):
    """Mamba boundary 4-state = (angle[H,N//2], ssm[H,P,N], kprev[H,R,N], vprev[H,P,R])."""
    zs = tiny_hybrid._zero_state()
    H, N, P, R = MT.H, MT.N, MT.P, MT.R
    expected = [(H, N // 2), (H, P, N), (H, R, N), (H, P, R)]
    for i, (tag, s) in enumerate(zs):
        if tag != "mamba":
            continue
        assert isinstance(s, tuple) and len(s) == 4
        assert [tuple(t.shape) for t in s] == expected


def test_zero_state_mamba_all_zeros(tiny_hybrid):
    zs = tiny_hybrid._zero_state()
    for tag, s in zs:
        if tag == "mamba":
            for t in s:
                assert torch.count_nonzero(t) == 0


def test_zero_state_inherits_dtype(tiny_hybrid):
    """State tensors follow the embedding dtype (the device/dtype carry comment)."""
    m = tiny_hybrid.double()
    zs = m._zero_state()
    for tag, s in zs:
        if tag == "mamba":
            for t in s:
                assert t.dtype == torch.float64


# ----------------------------------------------------------------------------
# prefill: shape + heterogeneous handoff structure
# ----------------------------------------------------------------------------
def test_prefill_returns_hidden_seq_and_states(tiny_hybrid):
    """prefill -> (hidden seq [T,D], per-layer handoff). NOTE: first element is hidden, NOT logits."""
    toks = torch.randint(0, 96, (5,))
    h, st = tiny_hybrid.prefill(toks)
    assert h.shape == (5, MT.D_MODEL)
    assert len(st) == len(tiny_hybrid.layers)
    for i, (tag, s) in enumerate(st):
        assert tag == ("mla" if i in tiny_hybrid.mla_pos else "mamba")


def test_prefill_mla_cache_grows_with_prompt(tiny_hybrid):
    """The MLA handoff cache is O(context): [T, D_LATENT]."""
    toks = torch.randint(0, 96, (9,))
    _h, st = tiny_hybrid.prefill(toks)
    for i in tiny_hybrid.mla_pos:
        tag, cache = st[i]
        assert tag == "mla"
        assert tuple(cache.shape) == (9, MLA.D_LATENT)


def test_prefill_mamba_state_shapes(tiny_hybrid):
    toks = torch.randint(0, 96, (5,))
    _h, st = tiny_hybrid.prefill(toks)
    H, N, P, R = MT.H, MT.N, MT.P, MT.R
    expected = [(H, N // 2), (H, P, N), (H, R, N), (H, P, R)]
    for i, (tag, s) in enumerate(st):
        if tag == "mamba":
            assert [tuple(t.shape) for t in s] == expected


# ----------------------------------------------------------------------------
# run_ref: shape + zero-state default
# ----------------------------------------------------------------------------
def test_run_ref_logits_shape(tiny_hybrid):
    toks = torch.randint(0, 96, (6,))
    logits = tiny_hybrid.run_ref(toks)
    assert logits.shape == (6, 96)


def test_run_ref_default_init_is_zero_state(tiny_hybrid):
    """run_ref(tokens) (no init) == run_ref(tokens, init=zero_state)."""
    toks = torch.randint(0, 96, (4,))
    a = tiny_hybrid.run_ref(toks)
    b = tiny_hybrid.run_ref(toks, init=tiny_hybrid._zero_state())
    assert torch.allclose(a, b, atol=1e-6)


def test_run_ref_does_not_mutate_passed_init(tiny_hybrid):
    """run_ref copies the mamba state (list(s)) so the caller's handoff is not clobbered."""
    m = tiny_hybrid.double()
    toks = torch.randint(0, 96, (3,))
    init = m._zero_state()
    # snapshot the mla cache identity + a mamba tensor
    snapshot = [(tag, (None if tag == "mla" else tuple(t.clone() for t in s))) for tag, s in init]
    m.run_ref(toks, init=init)
    for (tag, s), (_t0, s0) in zip(init, snapshot):
        if tag == "mamba":
            for t, t0 in zip(s, s0):
                assert torch.equal(t, t0), "run_ref must not mutate the caller's mamba state in place"


# ----------------------------------------------------------------------------
# (3) PREFIX STATE REUSE
# ----------------------------------------------------------------------------
def test_prefix_reuse_prefill_level_exact(tiny_hybrid):
    """prefill(suffix, init=prefill(prompt)) hidden == prefill(prompt+suffix)[plen:] (same chunked-scan path -> ~fp64 exact)."""
    m = tiny_hybrid.double()
    full = torch.randint(0, 96, (12,))
    plen = 7
    prompt, suffix = full[:plen], full[plen:]
    _hp, st = m.prefill(prompt)
    h_suffix, _ = m.prefill(suffix, init=st)
    h_full, _ = m.prefill(full)
    assert torch.allclose(h_suffix, h_full[plen:], atol=1e-10)


def test_prefix_reuse_run_ref_matches_full_decode(tiny_hybrid):
    """The audited DUET handoff invariant: prefill(prompt) state, then run_ref(suffix, init=state) logits
    == run_ref(prompt+suffix)[plen:]. The gap is the chunked-scan-prefill -> per-token-decode cross-path
    difference at the boundary; in fp64 it stays well under 1e-5."""
    m = tiny_hybrid.double()
    full = torch.randint(0, 96, (12,))
    plen = 7
    prompt, suffix = full[:plen], full[plen:]
    _h, st = m.prefill(prompt)
    lr_suffix = m.run_ref(suffix, init=st)
    lr_full = m.run_ref(full)
    assert lr_suffix.shape == (len(suffix), 96)
    assert torch.allclose(lr_suffix, lr_full[plen:], atol=1e-5)


def test_prefix_reuse_multi_split_consistent(tiny_hybrid):
    """Two-step resume (a -> b -> c via prefill chaining) == single prefill of the whole sequence."""
    m = tiny_hybrid.double()
    full = torch.randint(0, 96, (15,))
    a, b, c = full[:5], full[5:10], full[10:]
    _ha, sa = m.prefill(a)
    _hb, sb = m.prefill(b, init=sa)
    hc, _ = m.prefill(c, init=sb)
    h_full, _ = m.prefill(full)
    assert torch.allclose(hc, h_full[10:], atol=1e-9)


def test_prefix_reuse_exercises_both_layer_kinds(tiny_hybrid):
    """Sanity: the resumed handoff carries BOTH a non-empty mla cache and mamba 4-states across the split."""
    m = tiny_hybrid.double()
    prompt = torch.randint(0, 96, (6,))
    _h, st = m.prefill(prompt)
    tags = {tag for tag, _ in st}
    assert "mamba" in tags and "mla" in tags


# ----------------------------------------------------------------------------
# (4) generate: deterministic greedy, length cap, eos stop
# ----------------------------------------------------------------------------
def test_generate_greedy_deterministic(tiny_hybrid):
    prompt = torch.randint(0, 96, (5,))
    g1 = tiny_hybrid.generate(prompt, 10, temperature=0.0)
    g2 = tiny_hybrid.generate(prompt, 10, temperature=0.0)
    assert g1 == g2


def test_generate_length_le_max_new(tiny_hybrid):
    prompt = torch.randint(0, 96, (5,))
    for mx in (1, 3, 10):
        g = tiny_hybrid.generate(prompt, mx, temperature=0.0)
        assert 1 <= len(g) <= mx


def test_generate_returns_python_ints(tiny_hybrid):
    prompt = torch.randint(0, 96, (4,))
    g = tiny_hybrid.generate(prompt, 5, temperature=0.0)
    assert all(isinstance(t, int) for t in g)


def test_generate_stops_at_eos(tiny_hybrid):
    """eos is checked at loop top; once a sampled token equals eos, decode stops (eos is the last emitted)."""
    prompt = torch.randint(0, 96, (5,))
    g_free = tiny_hybrid.generate(prompt, 10, temperature=0.0)
    assert len(g_free) > 1  # need a repeated greedy token to detect the stop
    eos = g_free[-1]
    g_eos = tiny_hybrid.generate(prompt, 10, temperature=0.0, eos=eos)
    assert g_eos[-1] == eos
    assert len(g_eos) <= len(g_free)
    # the stop fires the step AFTER eos first appears -> output ends at the first eos occurrence
    first_eos = g_free.index(eos)
    assert len(g_eos) == first_eos + 1
    assert g_eos == g_free[:first_eos + 1]


def test_generate_first_token_matches_prefill_head(tiny_hybrid):
    """The first generated token is argmax of head(prefill(prompt)[-1]) at temperature=0."""
    m = tiny_hybrid
    prompt = torch.randint(0, 96, (5,))
    with torch.no_grad():
        h, _st = m.prefill(prompt)
        expected = int(m.head(h[-1]).argmax())
    g = m.generate(prompt, 3, temperature=0.0)
    assert g[0] == expected


def test_generate_eos_equal_first_token_yields_singleton(tiny_hybrid):
    """If eos == the very first sampled token, only that token is returned (eos still emitted once)."""
    m = tiny_hybrid
    prompt = torch.randint(0, 96, (5,))
    first = m.generate(prompt, 5, temperature=0.0)[0]
    g = m.generate(prompt, 5, temperature=0.0, eos=first)
    assert g == [first]


def test_generate_sampling_is_seed_reproducible(tiny_hybrid):
    """temperature>0 with an explicit generator is reproducible across calls."""
    prompt = torch.randint(0, 96, (5,))
    g1 = tiny_hybrid.generate(prompt, 8, temperature=1.0, top_p=0.9,
                              gen=torch.Generator().manual_seed(123))
    g2 = tiny_hybrid.generate(prompt, 8, temperature=1.0, top_p=0.9,
                              gen=torch.Generator().manual_seed(123))
    assert g1 == g2


# ----------------------------------------------------------------------------
# _sample helper
# ----------------------------------------------------------------------------
def test_sample_greedy_is_argmax():
    logit = torch.tensor([0.1, 5.0, -2.0, 0.3])
    assert HY._sample(logit, temperature=0.0, top_p=1.0) == 1


def test_sample_greedy_ignores_top_p():
    logit = torch.tensor([0.1, 5.0, -2.0, 0.3])
    assert HY._sample(logit, temperature=0.0, top_p=0.5) == 1


def test_sample_topp_keeps_at_least_one_token():
    """top_p with the exclusive-cumsum mask always keeps >=1 token (no empty distribution)."""
    logit = torch.randn(96)
    gen = torch.Generator().manual_seed(7)
    tok = HY._sample(logit, temperature=1.0, top_p=1e-9, gen=gen)
    assert 0 <= tok < 96


# ----------------------------------------------------------------------------
# (6) MLABlock.step vs forward_seq consistency
# ----------------------------------------------------------------------------
def test_mla_step_matches_forward_seq(tiny_hybrid):
    """Single-token cached decode == causal-prefix forward_seq (fp64 tight)."""
    blk = MLA.MLABlock().double().eval()
    T = 7
    x = torch.randn(T, MT.D_MODEL, dtype=torch.float64)
    with torch.no_grad():
        out_seq, cache_seq = blk.forward_seq(x)
        cache = None
        outs, caches = [], []
        for t in range(T):
            o, cache = blk.step(x[t], cache)
            outs.append(o)
        step_out = torch.stack(outs, 0)
    assert torch.allclose(out_seq, step_out, atol=1e-10)
    assert tuple(cache.shape) == tuple(cache_seq.shape) == (T, MLA.D_LATENT)
    assert torch.allclose(cache, cache_seq, atol=1e-12)


def test_mla_step_output_shapes():
    blk = MLA.MLABlock().eval()
    x = torch.randn(MT.D_MODEL)
    o, c = blk.step(x, None)
    assert o.shape == (MT.D_MODEL,)
    assert tuple(c.shape) == (1, MLA.D_LATENT)
    o2, c2 = blk.step(torch.randn(MT.D_MODEL), c)
    assert o2.shape == (MT.D_MODEL,)
    assert tuple(c2.shape) == (2, MLA.D_LATENT)


def test_mla_forward_seq_prefix_reuse():
    """MLA is O(ctx): forward_seq(suffix, kv_init=prefix_cache) == forward_seq(prefix+suffix)[plen:]."""
    blk = MLA.MLABlock().double().eval()
    full = torch.randn(11, MT.D_MODEL, dtype=torch.float64)
    plen = 4
    with torch.no_grad():
        _op, cp = blk.forward_seq(full[:plen])
        o_suffix, c_full2 = blk.forward_seq(full[plen:], kv_init=cp)
        o_full, c_full = blk.forward_seq(full)
    assert torch.allclose(o_suffix, o_full[plen:], atol=1e-10)
    assert torch.allclose(c_full2, c_full, atol=1e-12)


def test_mla_forward_seq_causal():
    """Causal: changing a LATE token must not change EARLY outputs of forward_seq."""
    blk = MLA.MLABlock().double().eval()
    x = torch.randn(6, MT.D_MODEL, dtype=torch.float64)
    with torch.no_grad():
        o1, _ = blk.forward_seq(x)
        x2 = x.clone()
        x2[-1] = torch.randn(MT.D_MODEL, dtype=torch.float64)  # perturb only the last token
        o2, _ = blk.forward_seq(x2)
    assert torch.allclose(o1[:-1], o2[:-1], atol=1e-10)
    assert not torch.allclose(o1[-1], o2[-1], atol=1e-6)


def test_mla_step_decode_after_prefill_matches_forward_seq():
    """MLA prefill -> step decode == full forward_seq (the per-block DUET handoff)."""
    blk = MLA.MLABlock().double().eval()
    full = torch.randn(9, MT.D_MODEL, dtype=torch.float64)
    plen = 5
    with torch.no_grad():
        _op, cache = blk.forward_seq(full[:plen])
        outs = []
        for t in range(plen, full.shape[0]):
            o, cache = blk.step(full[t], cache)
            outs.append(o)
        step_out = torch.stack(outs, 0)
        o_full, _ = blk.forward_seq(full)
    assert torch.allclose(step_out, o_full[plen:], atol=1e-10)


# ----------------------------------------------------------------------------
# run_twin (training forward) — arch-agnostic mirror
# ----------------------------------------------------------------------------
def test_run_twin_logits_shape(tiny_hybrid):
    toks = torch.randint(0, 96, (6,))
    logits, extra = tiny_hybrid.run_twin(toks)
    assert logits.shape == (6, 96)
    assert extra == []


def test_run_twin_collect_ssm_only_mamba_layers(tiny_hybrid):
    """collect_ssm gathers one SSM seq per MAMBA layer (MLA layers contribute none)."""
    toks = torch.randint(0, 96, (6,))
    _logits, extra = tiny_hybrid.run_twin(toks, collect_ssm=True)
    n_mamba = len(tiny_hybrid.layers) - len(tiny_hybrid.mla_pos)
    assert len(extra) == n_mamba


def test_run_twin_return_hiddens_one_per_layer(tiny_hybrid):
    toks = torch.randint(0, 96, (5,))
    _logits, extra = tiny_hybrid.run_twin(toks, return_hiddens=True)
    assert len(extra) == len(tiny_hybrid.layers)
    for h in extra:
        assert h.shape == (5, MT.D_MODEL)


# ----------------------------------------------------------------------------
# cache_serialize_state_hybrid — State-Cache floor structure
# ----------------------------------------------------------------------------
def test_cache_serialize_preserves_structure(tiny_hybrid):
    toks = torch.randint(0, 96, (5,))
    _h, st = tiny_hybrid.prefill(toks)
    ser = HY.cache_serialize_state_hybrid(st)
    assert len(ser) == len(st)
    for (tag0, _s0), (tag1, _s1) in zip(st, ser):
        assert tag0 == tag1


def test_cache_serialize_wraps_mamba_angle(tiny_hybrid):
    """The serialized mamba angle is wrapped to (-pi, pi]."""
    import math
    toks = torch.randint(0, 96, (8,))
    _h, st = tiny_hybrid.prefill(toks)
    ser = HY.cache_serialize_state_hybrid(st)
    for tag, s in ser:
        if tag == "mamba":
            angle = s[0]
            assert torch.all(angle > -math.pi - 1e-5)
            assert torch.all(angle <= math.pi + 1e-5)


def test_cache_serialize_quant_applied_to_all_tensors(tiny_hybrid):
    """An optional quant callable is applied to every stored tensor (mamba 4-tuple + mla latent)."""
    toks = torch.randint(0, 96, (5,))
    _h, st = tiny_hybrid.prefill(toks)
    sentinel = {"calls": 0}

    def q(t):
        sentinel["calls"] += 1
        return torch.zeros_like(t)

    ser = HY.cache_serialize_state_hybrid(st, quant=q)
    n_mamba = len(tiny_hybrid.layers) - len(tiny_hybrid.mla_pos)
    n_mla = len(tiny_hybrid.mla_pos)
    assert sentinel["calls"] == 4 * n_mamba + n_mla
    for tag, s in ser:
        if tag == "mamba":
            for t in s:
                assert torch.count_nonzero(t) == 0
        else:
            assert torch.count_nonzero(s) == 0
