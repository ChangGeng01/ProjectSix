"""Deploy-carry guard tests: mamba3_hybrid.resolve_ckpt (the ckpt -> device carry guard).

resolve_ckpt is the gate between the paid cloud checkpoint and an on-device export. It must:
  - REFUSE to silently export random weights (no CKPT, no FORCE_RANDOM -> SystemExit);
  - allow an explicit random-weight op-graph/speed probe (FORCE_RANDOM=1 -> (vocab, None));
  - treat the checkpoint as AUTHORITATIVE on vocab (closes the Granite-vocab mismatch);
  - FAIL-CLOSED on any incoherence vs the graph it is about to rebuild: wrong arch, wrong
    layer count, moved MLA placement, or changed per-layer config.

We also pin the deploy-side load_state_dict guard: the saved hybrid state_dict loads into a
fresh HybridM(96,8) with EMPTY missing+unexpected, and dropping one key makes missing non-empty
(so the assert-not-missing deploy guard would fire on a truncated/corrupt checkpoint).

These tests mutate process env (CKPT / FORCE_RANDOM / VOCAB) and the module-level LAYERS; an
autouse fixture snapshots and restores both so tests stay isolated.
"""
from __future__ import annotations

import os

import pytest
import torch

import mamba3_hybrid as HY
import mamba3_cloud_distill as CD
import mamba3_trainable as MT


# --------------------------------------------------------------------------- helpers / fixtures


@pytest.fixture(autouse=True)
def _clean_env_and_layers():
    """Snapshot the env keys resolve_ckpt reads + the module-level LAYERS save_ckpt reads; restore after."""
    saved_env = {k: os.environ.get(k) for k in ("CKPT", "FORCE_RANDOM", "VOCAB")}
    for k in saved_env:
        os.environ.pop(k, None)
    saved_layers = CD.LAYERS
    try:
        yield
    finally:
        for k, v in saved_env.items():
            if v is None:
                os.environ.pop(k, None)
            else:
                os.environ[k] = v
        CD.LAYERS = saved_layers


def _save_hybrid_ckpt(tmp_path, vocab=96, layers=8, name="ckpt.pt"):
    """Save a REAL hybrid checkpoint via the production save_ckpt. save_ckpt reads module-level
    CD.LAYERS for the stored 'layers' field, so pin it to the model's layer count for coherence."""
    CD.LAYERS = layers
    model = HY.HybridM(vocab, layers)
    opt = torch.optim.AdamW(model.parameters(), lr=1e-3)
    path = os.path.join(str(tmp_path), name)
    CD.save_ckpt(model, opt, 5, path)
    return path


def _resave(path, mutate, name=None):
    """Load a ckpt, apply mutate(dict) in place, re-save (optionally to a new name); return its path."""
    c = torch.load(path, map_location="cpu")
    mutate(c)
    out = path if name is None else os.path.join(os.path.dirname(path), name)
    torch.save(c, out)
    return out


# --------------------------------------------------------------------------- (1) refuse silent random


def test_no_ckpt_no_force_random_raises_system_exit():
    """The whole point of the guard: no CKPT + no FORCE_RANDOM must REFUSE (SystemExit), never
    silently export an untrained random-weight asset as if it were the distilled checkpoint."""
    assert os.environ.get("CKPT") is None
    assert os.environ.get("FORCE_RANDOM") is None
    with pytest.raises(SystemExit):
        HY.resolve_ckpt(96, 8)


def test_system_exit_message_mentions_ckpt():
    """The refusal must be actionable (tell the operator how to proceed) — not a bare exit."""
    with pytest.raises(SystemExit) as ei:
        HY.resolve_ckpt(96, 8)
    msg = str(ei.value)
    assert "CKPT" in msg
    assert "FORCE_RANDOM" in msg


def test_empty_ckpt_string_treated_as_unset():
    """CKPT="" (set-but-empty) is the same as unset — must NOT be read as a path; still refuses."""
    os.environ["CKPT"] = ""
    with pytest.raises(SystemExit):
        HY.resolve_ckpt(96, 8)


# --------------------------------------------------------------------------- (2) explicit random probe


def test_force_random_returns_default_vocab_and_none_state():
    """FORCE_RANDOM=1 with no CKPT = the sanctioned random-weight op-graph/speed probe:
    (default_vocab, None). None state_dict signals 'random init, do not load'."""
    os.environ["FORCE_RANDOM"] = "1"
    vocab, sd = HY.resolve_ckpt(96, 8)
    assert vocab == 96
    assert sd is None


def test_force_random_vocab_override():
    """When probing random, VOCAB env overrides default_vocab (probe at the real Granite vocab width)."""
    os.environ["FORCE_RANDOM"] = "1"
    os.environ["VOCAB"] = "128"
    vocab, sd = HY.resolve_ckpt(96, 8)
    assert vocab == 128
    assert sd is None


def test_force_random_returns_int_vocab():
    """VOCAB override is parsed to an int (Embedding(vocab, D) requires an int, not a str)."""
    os.environ["FORCE_RANDOM"] = "1"
    os.environ["VOCAB"] = "200"
    vocab, _ = HY.resolve_ckpt(96, 8)
    assert isinstance(vocab, int)
    assert vocab == 200


def test_force_random_only_when_exactly_1():
    """FORCE_RANDOM must be exactly "1" to bypass — any other truthy-looking value still refuses
    (fail-closed: 'true'/'yes'/'0' do NOT unlock a random export)."""
    for val in ("0", "true", "yes", "", "01"):
        os.environ["FORCE_RANDOM"] = val
        with pytest.raises(SystemExit):
            HY.resolve_ckpt(96, 8)


# --------------------------------------------------------------------------- (3) valid hybrid ckpt


def test_valid_hybrid_ckpt_returns_vocab_and_state(tmp_path):
    """A valid hybrid ckpt -> (vocab_from_ckpt, state_dict). The state_dict is the real model dict."""
    path = _save_hybrid_ckpt(tmp_path, vocab=96, layers=8)
    os.environ["CKPT"] = path
    vocab, sd = HY.resolve_ckpt(96, 8)
    assert vocab == 96
    assert sd is not None
    assert isinstance(sd, dict)
    assert len(sd) > 0


def test_ckpt_is_authoritative_on_vocab(tmp_path):
    """The checkpoint's vocab WINS over default_vocab (this is the audit fix that closes the
    4096-vs-Granite-100352 mismatch). Save at vocab=96, ask with default_vocab=12 -> get 96."""
    path = _save_hybrid_ckpt(tmp_path, vocab=96, layers=8)
    os.environ["CKPT"] = path
    vocab, sd = HY.resolve_ckpt(12, 8)
    assert vocab == 96


def test_valid_ckpt_state_dict_keys_match_fresh_model(tmp_path):
    """The returned state_dict keys are exactly a fresh HybridM(96,8)'s parameter keys."""
    path = _save_hybrid_ckpt(tmp_path, vocab=96, layers=8)
    os.environ["CKPT"] = path
    _, sd = HY.resolve_ckpt(96, 8)
    fresh = HY.HybridM(96, 8)
    assert set(sd.keys()) == set(fresh.state_dict().keys())


def test_ckpt_with_absent_optional_keys_passes(tmp_path):
    """layers/config/mla_positions are OPTIONAL in the guard (None -> skip). A minimal ckpt with
    only arch+vocab+model still resolves (back-compat with older checkpoints)."""
    path = _save_hybrid_ckpt(tmp_path, vocab=96, layers=8)
    minimal = _resave(path, lambda c: [c.pop(k, None) for k in ("layers", "config", "mla_positions")],
                       name="minimal.pt")
    os.environ["CKPT"] = minimal
    vocab, sd = HY.resolve_ckpt(96, 8)
    assert vocab == 96
    assert sd is not None


def test_ckpt_without_vocab_key_falls_back_to_default(tmp_path):
    """If a ckpt lacks the 'vocab' key, the guard returns default_vocab (not a crash)."""
    path = _save_hybrid_ckpt(tmp_path, vocab=96, layers=8)
    novocab = _resave(path, lambda c: c.pop("vocab", None), name="novocab.pt")
    os.environ["CKPT"] = novocab
    vocab, _ = HY.resolve_ckpt(77, 8)
    assert vocab == 77


# --------------------------------------------------------------------------- (4) wrong arch


def test_arch_mamba_ckpt_raises_assertion(tmp_path):
    """arch='mamba' through the HYBRID converter is the wrong converter -> AssertionError
    (rebuilding a HybridM graph from a pure-Mamba dict would be incoherent)."""
    path = _save_hybrid_ckpt(tmp_path, vocab=96, layers=8)
    bad = _resave(path, lambda c: c.__setitem__("arch", "mamba"), name="arch_mamba.pt")
    os.environ["CKPT"] = bad
    with pytest.raises(AssertionError):
        HY.resolve_ckpt(96, 8)


def test_arch_missing_raises_assertion(tmp_path):
    """A ckpt with no 'arch' key (c.get('arch') is None) is not 'hybrid' -> AssertionError."""
    path = _save_hybrid_ckpt(tmp_path, vocab=96, layers=8)
    bad = _resave(path, lambda c: c.pop("arch", None), name="arch_none.pt")
    os.environ["CKPT"] = bad
    with pytest.raises(AssertionError):
        HY.resolve_ckpt(96, 8)


# --------------------------------------------------------------------------- (5) layer-count mismatch


def test_ckpt_layers_mismatch_tampered_raises(tmp_path):
    """A ckpt whose stored 'layers' disagrees with the requested layers -> AssertionError
    (deploying an incoherent-depth graph). Tamper the field directly."""
    path = _save_hybrid_ckpt(tmp_path, vocab=96, layers=8)
    bad = _resave(path, lambda c: c.__setitem__("layers", 12), name="layers12.pt")
    os.environ["CKPT"] = bad
    with pytest.raises(AssertionError):
        HY.resolve_ckpt(96, 8)


def test_ckpt_layers_mismatch_via_request(tmp_path):
    """Same guard hit naturally: an 8-layer ckpt resolved while requesting 24 layers -> AssertionError."""
    path = _save_hybrid_ckpt(tmp_path, vocab=96, layers=8)
    os.environ["CKPT"] = path
    with pytest.raises(AssertionError):
        HY.resolve_ckpt(96, 24)


# --------------------------------------------------------------------------- (6) MLA placement mismatch


def test_tampered_mla_positions_raises(tmp_path):
    """The ckpt's stored mla_positions must equal the placement HybridM(layers) will build
    (for layers=8 that is [6]). A tampered [6,12] -> AssertionError (MLA placement mismatch)."""
    path = _save_hybrid_ckpt(tmp_path, vocab=96, layers=8)
    bad = _resave(path, lambda c: c.__setitem__("mla_positions", [6, 12]), name="mla612.pt")
    os.environ["CKPT"] = bad
    with pytest.raises(AssertionError):
        HY.resolve_ckpt(96, 8)


def test_tampered_mla_positions_empty_raises(tmp_path):
    """An empty mla_positions (pure-Mamba placement) != the expected [6] for layers=8 -> AssertionError."""
    path = _save_hybrid_ckpt(tmp_path, vocab=96, layers=8)
    bad = _resave(path, lambda c: c.__setitem__("mla_positions", []), name="mla_empty.pt")
    os.environ["CKPT"] = bad
    with pytest.raises(AssertionError):
        HY.resolve_ckpt(96, 8)


def test_expected_mla_placement_matches_built_model(tmp_path):
    """Sanity: the guard's expected MLA placement for layers=8 ([6]) equals what HybridM(96,8) builds
    (sorted mla_pos), so a faithfully-saved ckpt passes the placement check."""
    path = _save_hybrid_ckpt(tmp_path, vocab=96, layers=8)
    built = sorted(HY.HybridM(96, 8).mla_pos)
    assert built == [6]
    os.environ["CKPT"] = path
    _, sd = HY.resolve_ckpt(96, 8)            # must NOT raise: saved placement == built placement
    assert sd is not None


# --------------------------------------------------------------------------- (7) per-layer config mismatch


@pytest.mark.parametrize("idx,name", [(0, "D"), (1, "H"), (2, "P"), (3, "N"), (4, "R")])
def test_tampered_config_each_field_raises(tmp_path, idx, name):
    """Any change to the per-layer config tuple (D,H,P,N,R) -> AssertionError (the rebuilt graph
    would have a different shape than the trained weights). Tamper each field independently."""
    path = _save_hybrid_ckpt(tmp_path, vocab=96, layers=8)

    def mutate(c):
        cfg = list(c["config"])
        cfg[idx] = cfg[idx] + 7
        c["config"] = tuple(cfg)

    bad = _resave(path, mutate, name=f"cfg_{name}.pt")
    os.environ["CKPT"] = bad
    with pytest.raises(AssertionError):
        HY.resolve_ckpt(96, 8)


def test_faithful_config_matches_module_constants(tmp_path):
    """The config save_ckpt writes is exactly the module constants the guard checks against:
    (D_MODEL, H, P, N, R). A faithful ckpt passes the config check."""
    path = _save_hybrid_ckpt(tmp_path, vocab=96, layers=8)
    c = torch.load(path, map_location="cpu")
    assert list(c["config"]) == [MT.D_MODEL, MT.H, MT.P, MT.N, MT.R]
    os.environ["CKPT"] = path
    _, sd = HY.resolve_ckpt(96, 8)
    assert sd is not None


# --------------------------------------------------------------------------- deploy-side load guard


def test_state_dict_loads_clean_into_fresh_model(tmp_path):
    """The deploy guard: the resolved hybrid state_dict loads into a FRESH HybridM(96,8) with
    EMPTY missing AND unexpected keys (strict=False). The assert-not-missing guard would PASS."""
    path = _save_hybrid_ckpt(tmp_path, vocab=96, layers=8)
    os.environ["CKPT"] = path
    _, sd = HY.resolve_ckpt(96, 8)
    fresh = HY.HybridM(96, 8)
    res = fresh.load_state_dict(sd, strict=False)
    assert list(res.missing_keys) == []
    assert list(res.unexpected_keys) == []


def test_dropping_a_key_makes_missing_nonempty(tmp_path):
    """The deploy guard FIRES on a truncated checkpoint: drop one key from the state_dict and the
    fresh model reports it as missing (so assert-not-missing would catch the corrupt carry)."""
    path = _save_hybrid_ckpt(tmp_path, vocab=96, layers=8)
    os.environ["CKPT"] = path
    _, sd = HY.resolve_ckpt(96, 8)
    truncated = dict(sd)
    dropped = next(iter(truncated))
    del truncated[dropped]
    fresh = HY.HybridM(96, 8)
    res = fresh.load_state_dict(truncated, strict=False)
    assert list(res.missing_keys) == [dropped]
    assert list(res.unexpected_keys) == []


def test_dropping_the_head_norm_key_is_caught(tmp_path):
    """Targeted: dropping the tied-head RMS weight 'fw' (a non-layer top-level param) is caught by
    the missing-keys guard — these are exactly the keys a partial/old export would silently lack."""
    path = _save_hybrid_ckpt(tmp_path, vocab=96, layers=8)
    os.environ["CKPT"] = path
    _, sd = HY.resolve_ckpt(96, 8)
    assert "fw" in sd
    truncated = {k: v for k, v in sd.items() if k != "fw"}
    fresh = HY.HybridM(96, 8)
    res = fresh.load_state_dict(truncated, strict=False)
    assert "fw" in res.missing_keys


def test_extra_key_makes_unexpected_nonempty(tmp_path):
    """Symmetric guard: an EXTRA key in the dict shows up as unexpected (a stale/foreign export
    would be flagged), while missing stays empty."""
    path = _save_hybrid_ckpt(tmp_path, vocab=96, layers=8)
    os.environ["CKPT"] = path
    _, sd = HY.resolve_ckpt(96, 8)
    polluted = dict(sd)
    polluted["bogus_extra_param"] = torch.zeros(3)
    fresh = HY.HybridM(96, 8)
    res = fresh.load_state_dict(polluted, strict=False)
    assert list(res.missing_keys) == []
    assert "bogus_extra_param" in res.unexpected_keys
