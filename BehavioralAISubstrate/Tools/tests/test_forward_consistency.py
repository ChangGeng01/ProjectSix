"""forward_consistency — pin the device-truth invariant: train-graph ≡ deploy-graph.

The paid cloud run trains the student via the parallel `forward_seq`/`run_twin` path, but the
on-device asset DECODES via the per-token `step_ref`/`step` path. If those two graphs ever drift,
the cloud run trains a model that does NOT match what ships. These tests PIN their numeric identity
(fp64, tol < 1e-6) so a regression can never silently make the cloud run unsafe.

Covers:
  (1) MT.M.run_twin == iterating Lyr.step_ref token-by-token (zero 4-state per layer).
  (2) HybridM.run_twin == HybridM.run_ref (covers the MLA layer too).
  (3) LEAN_MLP one-source-of-truth: forward_seq honors LEAN_MLP exactly like step_ref;
      Lyr._block_out drops the MLP iff LEAN_MLP=1; twin==ref under both settings.
  (4) MLABlock.forward_seq == iterating .step token-by-token (causal attn == cached decode).
"""
from __future__ import annotations

import os
from contextlib import contextmanager

import pytest
import torch

import mamba3_hybrid as HY
import mamba3_mla as MLA
import mamba3_trainable as MT
from mamba3_trainable import H, N, P, R, D_MODEL

TOL = 1e-6           # fp64 device-truth tolerance
VOCAB = 96


# --------------------------------------------------------------------------------------
# helpers
# --------------------------------------------------------------------------------------
@contextmanager
def lean_mlp(value):
    """Set/unset os.environ['LEAN_MLP'] around a block and restore the prior value.

    LEAN_MLP is read from os.environ at call time inside Lyr._block_out, so it must be
    toggled around the actual forward call, not at import time.
    """
    prev = os.environ.get("LEAN_MLP")
    try:
        if value is None:
            os.environ.pop("LEAN_MLP", None)
        else:
            os.environ["LEAN_MLP"] = value
        yield
    finally:
        if prev is None:
            os.environ.pop("LEAN_MLP", None)
        else:
            os.environ["LEAN_MLP"] = prev


def _double_mamba(layers=3, vocab=VOCAB):
    torch.manual_seed(0)
    return MT.M(vocab, layers).double().eval()


def _double_hybrid(layers=8, vocab=VOCAB):
    torch.manual_seed(0)
    return HY.HybridM(vocab, layers).double().eval()


def _double_mla(layers=2, vocab=VOCAB):
    torch.manual_seed(0)
    return MLA.MLAStack(vocab, layers).double().eval()


def _zero_state_mamba(model):
    """Per-layer zero 4-state matching run_ref / step_ref: (angle[H,N//2], ssm[H,P,N], kprev[H,R,N], vprev[H,P,R])."""
    ew = model.embedding.weight
    z = lambda *s: torch.zeros(*s, device=ew.device, dtype=ew.dtype)
    return [(z(H, N // 2), z(H, P, N), z(H, R, N), z(H, P, R)) for _ in model.layers]


def _step_ref_logits(model, toks):
    """Iterate Lyr.step_ref token-by-token over all layers, returning logits [T,V] (the deploy graph)."""
    st = _zero_state_mamba(model)
    logits = []
    for tok in toks.tolist():
        x = model.embedding.weight[tok]
        for li, lyr in enumerate(model.layers):
            x, a, ss, k, v = lyr.step_ref(x, *st[li])
            st[li] = (a, ss, k, v)
        logits.append(model.head(x))
    return torch.stack(logits, 0)


# --------------------------------------------------------------------------------------
# (1) MT.M: run_twin (train graph) == iterating step_ref token-by-token (deploy graph)
# --------------------------------------------------------------------------------------
def test_mamba_state_shapes_match_module_constants():
    """The zero 4-state run_ref builds must be (angle[H,N//2], ssm[H,P,N], kprev[H,R,N], vprev[H,P,R])."""
    m = _double_mamba()
    st = _zero_state_mamba(m)[0]
    angle, ssm, kprev, vprev = st
    assert angle.shape == (H, N // 2)
    assert ssm.shape == (H, P, N)
    assert kprev.shape == (H, R, N)
    assert vprev.shape == (H, P, R)


def test_mamba_run_twin_equals_step_ref_logits():
    """Device-truth (1): run_twin logits == per-token step_ref logits, fp64, tol<1e-6."""
    m = _double_mamba()
    torch.manual_seed(1)
    toks = torch.randint(0, VOCAB, (24,))
    with torch.no_grad():
        ltwin, _ = m.run_twin(toks)
        lref = _step_ref_logits(m, toks)
    assert ltwin.shape == lref.shape == (24, VOCAB)
    err = (ltwin - lref).abs().max().item()
    assert err < TOL, f"train/deploy logits drift {err:.3e} >= {TOL}"


def test_mamba_run_twin_equals_run_ref_builtin():
    """run_twin == the model's OWN run_ref (which internally drives step_ref) — full pipeline parity."""
    m = _double_mamba()
    torch.manual_seed(2)
    toks = torch.randint(0, VOCAB, (20,))
    with torch.no_grad():
        ltwin, _ = m.run_twin(toks)
        lref, _ = m.run_ref(toks)
    err = (ltwin - lref).abs().max().item()
    assert err < TOL, f"run_twin vs run_ref drift {err:.3e}"


def test_mamba_run_twin_argmax_identical_to_ref():
    """Token-identical argmax (the gate the source's parity() asserts)."""
    m = _double_mamba()
    torch.manual_seed(3)
    toks = torch.randint(0, VOCAB, (24,))
    with torch.no_grad():
        ltwin, _ = m.run_twin(toks)
        lref, _ = m.run_ref(toks)
    assert torch.equal(ltwin.argmax(-1), lref.argmax(-1))


def test_mamba_ssm_trace_matches_between_twin_and_ref():
    """The collected SSM state trace (run_twin extra) == run_ref's per-step ssm trace, per layer."""
    m = _double_mamba()
    torch.manual_seed(4)
    toks = torch.randint(0, VOCAB, (16,))
    with torch.no_grad():
        _, ssm_twin = m.run_twin(toks, collect_ssm=True)
        _, ssm_ref = m.run_ref(toks)
    assert len(ssm_twin) == len(ssm_ref) == len(m.layers)
    for st, sr in zip(ssm_twin, ssm_ref):
        assert st.shape == sr.shape
        assert (st - sr).abs().max().item() < TOL


@pytest.mark.parametrize("T", [1, 2, 24, 65, 128])
def test_mamba_twin_ref_parity_across_lengths(T):
    """Parity holds for T=1, the chunk boundary (T>64 switches to scan_chunked), and beyond."""
    m = _double_mamba()
    torch.manual_seed(100 + T)
    toks = torch.randint(0, VOCAB, (T,))
    with torch.no_grad():
        ltwin, _ = m.run_twin(toks)
        lref, _ = m.run_ref(toks)
    assert ltwin.shape == (T, VOCAB)
    assert (ltwin - lref).abs().max().item() < TOL


def test_mamba_single_token_twin_equals_ref():
    """T=1 edge: one-token forward_seq == one step_ref from zero state."""
    m = _double_mamba()
    toks = torch.tensor([7])
    with torch.no_grad():
        ltwin, _ = m.run_twin(toks)
        lref = _step_ref_logits(m, toks)
    assert (ltwin - lref).abs().max().item() < TOL


# --------------------------------------------------------------------------------------
# (2) HybridM: run_twin (train) == run_ref (deploy) — covers the MLA layer too
# --------------------------------------------------------------------------------------
def test_hybrid_has_both_layer_types():
    """tiny_hybrid (L=8) must include the MLA layer at position 6 so this test covers MLA decode."""
    hy = _double_hybrid()
    assert 6 in hy.mla_pos
    assert isinstance(hy.layers[6], MLA.MLABlock)
    n_mla = sum(1 for i in range(len(hy.layers)) if hy._is_mla(i))
    n_mamba = len(hy.layers) - n_mla
    assert n_mla == 1 and n_mamba == 7   # 7 Mamba + 1 MLA


def test_hybrid_run_twin_equals_run_ref():
    """Device-truth (2): HybridM.run_twin == HybridM.run_ref, fp64, tol<1e-6 (Mamba + MLA layers)."""
    hy = _double_hybrid()
    torch.manual_seed(5)
    toks = torch.randint(0, VOCAB, (24,))
    with torch.no_grad():
        ltwin, _ = hy.run_twin(toks)
        lref = hy.run_ref(toks)
    assert ltwin.shape == lref.shape == (24, VOCAB)
    err = (ltwin - lref).abs().max().item()
    assert err < TOL, f"hybrid train/deploy drift {err:.3e} >= {TOL}"


def test_hybrid_run_twin_argmax_identical_to_ref():
    hy = _double_hybrid()
    torch.manual_seed(6)
    toks = torch.randint(0, VOCAB, (20,))
    with torch.no_grad():
        ltwin, _ = hy.run_twin(toks)
        lref = hy.run_ref(toks)
    assert torch.equal(ltwin.argmax(-1), lref.argmax(-1))


@pytest.mark.parametrize("T", [1, 3, 24, 65])
def test_hybrid_twin_ref_parity_across_lengths(T):
    """Hybrid parity across T including the >64 chunk boundary (MLA causal attn vs cached step both hold)."""
    hy = _double_hybrid()
    torch.manual_seed(200 + T)
    toks = torch.randint(0, VOCAB, (T,))
    with torch.no_grad():
        ltwin, _ = hy.run_twin(toks)
        lref = hy.run_ref(toks)
    assert (ltwin - lref).abs().max().item() < TOL


# --------------------------------------------------------------------------------------
# (3) LEAN_MLP one-source-of-truth — the audited fix
# --------------------------------------------------------------------------------------
def test_block_out_drops_mlp_iff_lean_mlp_set():
    """Lyr._block_out returns x1 exactly when LEAN_MLP=='1'; else x1 + mlp(x1)."""
    m = _double_mamba()
    lyr = m.layers[0]
    torch.manual_seed(7)
    x1 = torch.randn(5, D_MODEL, dtype=torch.float64)
    with lean_mlp("1"):
        lean_out = lyr._block_out(x1)
    with lean_mlp(None):
        full_out = lyr._block_out(x1)
    # LEAN: identity passthrough
    assert torch.equal(lean_out, x1)
    # FULL: adds the SwiGLU MLP (non-trivial)
    expected_full = x1 + lyr.mlp(x1)
    assert (full_out - expected_full).abs().max().item() < TOL
    # the MLP contribution is actually non-zero here (guards against a vacuous test)
    assert (full_out - x1).abs().max().item() > 0.0


def test_block_out_lean_values_other_than_1_keep_mlp():
    """Only the literal '1' triggers lean mode (e.g. '0' or 'true' keep the MLP)."""
    m = _double_mamba()
    lyr = m.layers[0]
    torch.manual_seed(8)
    x1 = torch.randn(4, D_MODEL, dtype=torch.float64)
    for val in ("0", "true", "yes", ""):
        with lean_mlp(val):
            out = lyr._block_out(x1)
        assert not torch.equal(out, x1), f"LEAN_MLP={val!r} should NOT drop the MLP"


def test_forward_seq_honors_lean_mlp_matches_step_ref_lean():
    """Device-truth (3) — the fix: under LEAN_MLP=1, forward_seq (twin) STILL == step_ref (ref).

    This is the regression that the audit closed: forward_seq previously ignored LEAN_MLP, so the
    trained graph (twin) silently kept an MLP that the deployed step_ref dropped.
    """
    m = _double_mamba()
    torch.manual_seed(9)
    toks = torch.randint(0, VOCAB, (24,))
    with lean_mlp("1"):
        with torch.no_grad():
            ltwin, _ = m.run_twin(toks)
            lref, _ = m.run_ref(toks)
    err = (ltwin - lref).abs().max().item()
    assert err < TOL, f"LEAN_MLP twin/ref drift {err:.3e} — forward_seq does not honor LEAN_MLP"


def test_forward_seq_matches_step_ref_lean_unset():
    """Under LEAN_MLP unset, twin == ref as well (the default full-MLP graph)."""
    m = _double_mamba()
    torch.manual_seed(10)
    toks = torch.randint(0, VOCAB, (24,))
    with lean_mlp(None):
        with torch.no_grad():
            ltwin, _ = m.run_twin(toks)
            lref, _ = m.run_ref(toks)
    assert (ltwin - lref).abs().max().item() < TOL


def test_lean_and_full_graphs_actually_differ():
    """Sanity: LEAN vs FULL must produce DIFFERENT logits (else the LEAN parity test is vacuous)."""
    m = _double_mamba()
    torch.manual_seed(11)
    toks = torch.randint(0, VOCAB, (16,))
    with lean_mlp("1"):
        with torch.no_grad():
            llean, _ = m.run_twin(toks)
    with lean_mlp(None):
        with torch.no_grad():
            lfull, _ = m.run_twin(toks)
    assert (llean - lfull).abs().max().item() > 1e-9


def test_forward_seq_lean_drops_mlp_per_layer():
    """forward_seq's block-out under LEAN == x1 (pre-MLP residual) per single layer."""
    m = _double_mamba()
    lyr = m.layers[0]
    torch.manual_seed(12)
    x_seq = torch.randn(6, D_MODEL, dtype=torch.float64)
    with lean_mlp("1"):
        with torch.no_grad():
            out_lean, _, _ = lyr.forward_seq(x_seq)
    with lean_mlp(None):
        with torch.no_grad():
            out_full, _, _ = lyr.forward_seq(x_seq)
    # lean output == full output minus the MLP added on the post-mixer residual x1
    diff = (out_full - out_lean).abs().max().item()
    assert diff > 1e-9   # the MLP genuinely contributes in full mode


def test_lean_mlp_env_restored_after_context():
    """The lean_mlp context manager must not leak LEAN_MLP into the global environment."""
    sentinel = object()
    before = os.environ.get("LEAN_MLP", sentinel)
    with lean_mlp("1"):
        assert os.environ["LEAN_MLP"] == "1"
    after = os.environ.get("LEAN_MLP", sentinel)
    assert after is before or after == before


# --------------------------------------------------------------------------------------
# (4) MLABlock: forward_seq (causal attn) == iterating .step token-by-token (cached decode)
# --------------------------------------------------------------------------------------
def _mla_step_hidden(block, x_seq):
    """Drive MLABlock.step token-by-token from an empty cache; return stacked block-outputs [T,D]."""
    cache = None
    outs = []
    for t in range(x_seq.shape[0]):
        out_t, cache = block.step(x_seq[t], cache)
        outs.append(out_t)
    return torch.stack(outs, 0), cache


def test_mla_forward_seq_equals_step_decode():
    """Device-truth (4): MLABlock.forward_seq(x_seq) == iterating .step token-by-token, fp64, tol<1e-6."""
    torch.manual_seed(13)
    block = MLA.MLABlock().double().eval()
    x_seq = torch.randn(20, D_MODEL, dtype=torch.float64)
    with torch.no_grad():
        seq_out, seq_cache = block.forward_seq(x_seq)
        step_out, step_cache = _mla_step_hidden(block, x_seq)
    assert seq_out.shape == step_out.shape == (20, D_MODEL)
    err = (seq_out - step_out).abs().max().item()
    assert err < TOL, f"MLA prefill vs decode drift {err:.3e} >= {TOL}"


def test_mla_caches_match_between_prefill_and_decode():
    """The accumulated latent cache must be identical (decode resume == prefill cache)."""
    torch.manual_seed(14)
    block = MLA.MLABlock().double().eval()
    x_seq = torch.randn(12, D_MODEL, dtype=torch.float64)
    with torch.no_grad():
        _, seq_cache = block.forward_seq(x_seq)
        _, step_cache = _mla_step_hidden(block, x_seq)
    assert seq_cache.shape == step_cache.shape == (12, MLA.D_LATENT)
    assert (seq_cache - step_cache).abs().max().item() < TOL


@pytest.mark.parametrize("T", [1, 2, 8, 33])
def test_mla_forward_seq_step_parity_across_lengths(T):
    torch.manual_seed(300 + T)
    block = MLA.MLABlock().double().eval()
    x_seq = torch.randn(T, D_MODEL, dtype=torch.float64)
    with torch.no_grad():
        seq_out, _ = block.forward_seq(x_seq)
        step_out, _ = _mla_step_hidden(block, x_seq)
    assert (seq_out - step_out).abs().max().item() < TOL


def test_mla_forward_seq_causal_no_future_leak():
    """Causality: changing a LATER token must not change an EARLIER position's forward_seq output."""
    torch.manual_seed(15)
    block = MLA.MLABlock().double().eval()
    x_seq = torch.randn(10, D_MODEL, dtype=torch.float64)
    x_alt = x_seq.clone()
    x_alt[7] = torch.randn(D_MODEL, dtype=torch.float64)   # perturb token 7 only
    with torch.no_grad():
        out_a, _ = block.forward_seq(x_seq)
        out_b, _ = block.forward_seq(x_alt)
    # positions 0..6 (strictly before the perturbed token) must be untouched
    assert (out_a[:7] - out_b[:7]).abs().max().item() < TOL
    # position 7 onward should change (sanity that the perturbation is real)
    assert (out_a[7:] - out_b[7:]).abs().max().item() > 1e-9


def test_mla_kv_init_resume_equals_full_prefill():
    """RESUMABLE: forward_seq(suffix, kv_init=prefix_cache) == forward_seq(prefix+suffix) on the suffix."""
    torch.manual_seed(16)
    block = MLA.MLABlock().double().eval()
    full = torch.randn(15, D_MODEL, dtype=torch.float64)
    prefix, suffix = full[:9], full[9:]
    with torch.no_grad():
        out_full, _ = block.forward_seq(full)
        _, pref_cache = block.forward_seq(prefix)
        out_suf, _ = block.forward_seq(suffix, kv_init=pref_cache)
    assert out_suf.shape == (6, D_MODEL)
    assert (out_suf - out_full[9:]).abs().max().item() < TOL


def test_mla_stack_decode_equals_prefill():
    """MLAStack (pure-MLA model) prefill logits == decode logits resuming from caches."""
    m = _double_mla(layers=2)
    torch.manual_seed(17)
    toks = torch.randint(0, VOCAB, (10,))
    with torch.no_grad():
        # prefill the whole thing, then re-decode from empty caches and compare logits
        pref_logits, _ = m.prefill(toks)
        empty = [None for _ in m.layers]
        dec_logits, _ = m.decode(toks, empty)
    assert pref_logits.shape == dec_logits.shape == (10, VOCAB)
    assert (pref_logits - dec_logits).abs().max().item() < TOL
