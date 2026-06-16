"""Cloud-distill INTEGRATION invariants — pins the audited safety contract of the paid RunPod run.

Covers (from mamba3_cloud_distill.py):
  - build_cache fingerprint + CACHE-POLLUTION GUARD (same extra_fp OK; drift → SystemExit)
  - save_ckpt atomic write + the exact carry keys + arch tag (hybrid vs mamba)
  - decode_parity DEVICE-TRUTH gate (run_twin ≡ run_ref → argmax_agreement≈1.0; graceful skip w/o run_ref)
  - frozen eval-set persist round-trip (atomic torch.save + os.replace → byte-identical input_ids)
  - _content_fp-style content hash stability

CPU-only. The module resolves DEV=cuda→mps→cpu at import; this Mac picks mps, but decode_parity moves ids to
DEV while deepcopy'd students stay on CPU — so every test that touches DEV pins it to "cpu" (the cloud run is
cuda; the CPU pin is the legitimate offline-test path and matches the suite's CPU-only contract).
"""
from __future__ import annotations

import hashlib
import json
import os

import pytest
import torch

import mamba3_cloud_distill as CD
import mamba3_hybrid as HY
import mamba3_trainable as MT
import mamba3_raft as RAFT


@pytest.fixture(autouse=True)
def _force_cpu(monkeypatch):
    """The paid run is cuda; offline tests are CPU-only. Pin DEV so .to(DEV) doesn't split the
    deepcopy'd-on-CPU student from its mps-bound ids (a test-env artifact, not the cloud path)."""
    monkeypatch.setattr(CD, "DEV", "cpu")
    monkeypatch.setattr(RAFT, "DEV", "cpu")
    yield


# ---------------------------------------------------------------------------
# (1) build_cache fingerprint + CACHE-POLLUTION GUARD
# ---------------------------------------------------------------------------

def test_build_cache_writes_fingerprint_on_empty_train(tmp_path):
    """train=[] makes ZERO teacher calls (loop body never runs) yet still writes the fingerprint."""
    cdir = tmp_path / "cache"
    CD.build_cache(None, [], str(cdir), extra_fp="dfp")   # teacher=None is safe: no example → never called
    fpf = cdir / "fingerprint.txt"
    assert fpf.exists()
    assert len(fpf.read_text().strip()) == 16            # sha256 hexdigest()[:16]


def test_build_cache_fingerprint_is_16_hex(tmp_path):
    CD.build_cache(None, [], str(tmp_path), extra_fp="x")
    fp = (tmp_path / "fingerprint.txt").read_text().strip()
    int(fp, 16)                                          # is valid hex
    assert all(c in "0123456789abcdef" for c in fp)


def test_build_cache_same_extra_fp_is_idempotent(tmp_path):
    """Re-running with the SAME extra_fp must NOT raise (legit resume of a cached run)."""
    CD.build_cache(None, [], str(tmp_path), extra_fp="same")
    fp1 = (tmp_path / "fingerprint.txt").read_text()
    CD.build_cache(None, [], str(tmp_path), extra_fp="same")   # no raise
    fp2 = (tmp_path / "fingerprint.txt").read_text()
    assert fp1 == fp2                                          # unchanged


def test_build_cache_different_extra_fp_raises_drift(tmp_path):
    """The pollution guard: a DIFFERENT extra_fp (eval/data content changed) must REFUSE loudly."""
    CD.build_cache(None, [], str(tmp_path), extra_fp="orig")
    with pytest.raises(SystemExit) as ei:
        CD.build_cache(None, [], str(tmp_path), extra_fp="DRIFTED")
    assert "CACHE CONFIG DRIFT" in str(ei.value)


def test_build_cache_data_hash_in_fingerprint(tmp_path):
    """extra_fp (the eval/data content hash) is folded into the fingerprint → distinct data ⇒ distinct fp."""
    d1, d2 = tmp_path / "a", tmp_path / "b"
    CD.build_cache(None, [], str(d1), extra_fp="data-A")
    CD.build_cache(None, [], str(d2), extra_fp="data-B")
    assert (d1 / "fingerprint.txt").read_text() != (d2 / "fingerprint.txt").read_text()


def test_build_cache_drift_message_names_the_dir(tmp_path):
    CD.build_cache(None, [], str(tmp_path), extra_fp="one")
    with pytest.raises(SystemExit) as ei:
        CD.build_cache(None, [], str(tmp_path), extra_fp="two")
    msg = str(ei.value)
    assert str(tmp_path) in msg                                # points at the offending cache dir
    assert "POLLUTE" in msg                                    # loud about why


def test_build_cache_creates_dir_if_missing(tmp_path):
    nested = tmp_path / "deep" / "nested" / "cache"
    assert not nested.exists()
    CD.build_cache(None, [], str(nested), extra_fp="z")
    assert nested.is_dir() and (nested / "fingerprint.txt").exists()


def test_build_cache_fp_tracks_n_train(tmp_path, monkeypatch):
    """n_train enters the fingerprint payload: same dir + extra_fp but a different train length drifts."""
    ex = {"input_ids": torch.zeros(2, dtype=torch.long), "prompt_len": 1}
    CD.build_cache(None, [], str(tmp_path), extra_fp="k")      # n_train=0
    # A non-empty train of the SAME extra_fp now has n_train=1 → fingerprint differs → drift guard fires.
    # Use a teacher stub that would error if (wrongly) called, proving the guard trips BEFORE any forward.
    def _boom(_ids):
        raise AssertionError("teacher must not be called once drift is detected")
    with pytest.raises(SystemExit) as ei:
        CD.build_cache(_boom, [dict(ex)], str(tmp_path), extra_fp="k")
    assert "CACHE CONFIG DRIFT" in str(ei.value)


# ---------------------------------------------------------------------------
# (2) save_ckpt: atomic write, carry keys, arch tag
# ---------------------------------------------------------------------------

CKPT_KEYS = {"model", "opt", "step", "layers", "config", "arch", "vocab", "mla_positions", "sched"}


def _load(path):
    return torch.load(path, map_location="cpu", weights_only=False)


def test_save_ckpt_hybrid_has_all_keys(tmp_path, tiny_hybrid):
    opt = torch.optim.AdamW(tiny_hybrid.parameters(), lr=1e-3)
    p = str(tmp_path / "ckpt.pt")
    CD.save_ckpt(tiny_hybrid, opt, 12, p)
    st = _load(p)
    assert set(st.keys()) == CKPT_KEYS


def test_save_ckpt_arch_is_hybrid_for_HybridM(tmp_path, tiny_hybrid):
    opt = torch.optim.AdamW(tiny_hybrid.parameters(), lr=1e-3)
    p = str(tmp_path / "ckpt.pt")
    CD.save_ckpt(tiny_hybrid, opt, 1, p)
    assert _load(p)["arch"] == "hybrid"


def test_save_ckpt_arch_is_mamba_for_M(tmp_path, tiny_mamba):
    opt = torch.optim.AdamW(tiny_mamba.parameters(), lr=1e-3)
    p = str(tmp_path / "ckpt.pt")
    CD.save_ckpt(tiny_mamba, opt, 1, p)
    st = _load(p)
    assert st["arch"] == "mamba"
    assert st["mla_positions"] is None                         # mamba has no MLA positions


def test_save_ckpt_step_and_vocab_carried(tmp_path, tiny_hybrid, vocab):
    opt = torch.optim.AdamW(tiny_hybrid.parameters(), lr=1e-3)
    p = str(tmp_path / "ckpt.pt")
    CD.save_ckpt(tiny_hybrid, opt, 99, p)
    st = _load(p)
    assert st["step"] == 99
    assert st["vocab"] == vocab                                # from embedding.weight.shape[0]


def test_save_ckpt_config_is_locked_per_layer_tuple(tmp_path, tiny_hybrid):
    """config pins the proven per-layer geometry (D, H, P, N, R) for the converter to rebuild."""
    opt = torch.optim.AdamW(tiny_hybrid.parameters(), lr=1e-3)
    p = str(tmp_path / "ckpt.pt")
    CD.save_ckpt(tiny_hybrid, opt, 1, p)
    cfg = _load(p)["config"]
    assert tuple(cfg) == (MT.D_MODEL, MT.H, MT.P, MT.N, MT.R)


def test_save_ckpt_layers_is_global_LAYERS(tmp_path, tiny_hybrid):
    """save_ckpt persists the module-level LAYERS (the cloud target), not the tiny test model's depth."""
    opt = torch.optim.AdamW(tiny_hybrid.parameters(), lr=1e-3)
    p = str(tmp_path / "ckpt.pt")
    CD.save_ckpt(tiny_hybrid, opt, 1, p)
    assert _load(p)["layers"] == CD.LAYERS


def test_save_ckpt_mla_positions_sorted_for_hybrid(tmp_path, tiny_hybrid):
    """mla_positions = sorted(student.mla_pos); for L=8 the only MLA index < 8 is 6."""
    opt = torch.optim.AdamW(tiny_hybrid.parameters(), lr=1e-3)
    p = str(tmp_path / "ckpt.pt")
    CD.save_ckpt(tiny_hybrid, opt, 1, p)
    mp = _load(p)["mla_positions"]
    assert mp == sorted(tiny_hybrid.mla_pos)
    assert mp == sorted(mp)                                    # is actually sorted (list)
    assert 6 in mp


def test_save_ckpt_sched_state_carried_when_present(tmp_path, tiny_hybrid):
    opt = torch.optim.AdamW(tiny_hybrid.parameters(), lr=1e-3)

    class _Sched:
        def state_dict(self):
            return {"rng_step": 1234}

    p = str(tmp_path / "ckpt.pt")
    CD.save_ckpt(tiny_hybrid, opt, 1, p, sched=_Sched())
    assert _load(p)["sched"] == {"rng_step": 1234}


def test_save_ckpt_sched_none_by_default(tmp_path, tiny_hybrid):
    opt = torch.optim.AdamW(tiny_hybrid.parameters(), lr=1e-3)
    p = str(tmp_path / "ckpt.pt")
    CD.save_ckpt(tiny_hybrid, opt, 1, p)
    assert _load(p)["sched"] is None


def test_save_ckpt_model_state_roundtrips(tmp_path, tiny_hybrid, vocab):
    """The saved model state_dict reloads into a fresh same-shape model exactly."""
    opt = torch.optim.AdamW(tiny_hybrid.parameters(), lr=1e-3)
    p = str(tmp_path / "ckpt.pt")
    CD.save_ckpt(tiny_hybrid, opt, 1, p)
    fresh = HY.HybridM(vocab, 8).eval()
    fresh.load_state_dict(_load(p)["model"])                   # raises on any key/shape mismatch
    for k, v in tiny_hybrid.state_dict().items():
        assert torch.equal(v, fresh.state_dict()[k])


def test_save_ckpt_optimizer_state_carried(tmp_path, tiny_hybrid):
    opt = torch.optim.AdamW(tiny_hybrid.parameters(), lr=1e-3)
    p = str(tmp_path / "ckpt.pt")
    CD.save_ckpt(tiny_hybrid, opt, 1, p)
    fresh_opt = torch.optim.AdamW(tiny_hybrid.parameters(), lr=1e-3)
    saved_opt = _load(p)["opt"]
    fresh_opt.load_state_dict(saved_opt)                       # must be a valid AdamW state (raises otherwise)
    assert "param_groups" in saved_opt and "state" in saved_opt
    assert fresh_opt.state_dict()["param_groups"][0]["lr"] == 1e-3


def test_save_ckpt_is_atomic_no_tmp_left(tmp_path, tiny_hybrid):
    """Atomic save_ckpt pattern: write .tmp then os.replace → no .tmp residue, final file present."""
    opt = torch.optim.AdamW(tiny_hybrid.parameters(), lr=1e-3)
    p = tmp_path / "ckpt.pt"
    CD.save_ckpt(tiny_hybrid, opt, 1, str(p))
    assert p.exists()
    assert not (tmp_path / "ckpt.pt.tmp").exists()


def test_save_ckpt_overwrites_in_place(tmp_path, tiny_hybrid):
    """A second save to the SAME path (different step) replaces atomically — resume writes ckpt_latest repeatedly."""
    opt = torch.optim.AdamW(tiny_hybrid.parameters(), lr=1e-3)
    p = str(tmp_path / "ckpt.pt")
    CD.save_ckpt(tiny_hybrid, opt, 5, p)
    CD.save_ckpt(tiny_hybrid, opt, 500, p)
    assert _load(p)["step"] == 500
    assert not os.path.exists(p + ".tmp")


# ---------------------------------------------------------------------------
# (3) decode_parity DEVICE-TRUTH gate
# ---------------------------------------------------------------------------

def test_decode_parity_agreement_is_one(tiny_hybrid, eval_examples):
    """run_twin (parallel/eval graph) ≡ run_ref (sequential/device graph) → perfect argmax agreement."""
    r = CD.decode_parity(tiny_hybrid, eval_examples())
    assert r["argmax_agreement"] == pytest.approx(1.0)


def test_decode_parity_logit_err_finite_and_small(tiny_hybrid, eval_examples):
    r = CD.decode_parity(tiny_hybrid, eval_examples())
    assert r["logit_max_err"] is not None
    import math
    assert math.isfinite(r["logit_max_err"])
    assert r["logit_max_err"] >= 0.0
    assert r["logit_max_err"] < 1.0                            # twin≡ref: only fp16 rounding separates them


def test_decode_parity_n_positions_positive(tiny_hybrid, eval_examples):
    r = CD.decode_parity(tiny_hybrid, eval_examples())
    assert r["n_positions"] > 0


def test_decode_parity_reports_dtype_fp16(tiny_hybrid, eval_examples):
    r = CD.decode_parity(tiny_hybrid, eval_examples())
    assert r["dtype"] == "fp16"


def test_decode_parity_n_examples_capped(tiny_hybrid, eval_examples):
    """max_ex bounds how many examples the parity gate touches."""
    ex = eval_examples(n=6)
    r = CD.decode_parity(tiny_hybrid, ex, max_ex=2)
    assert r["n_examples"] == 2


def test_decode_parity_n_examples_min_of_n_and_len(tiny_hybrid, eval_examples):
    ex = eval_examples(n=3)
    r = CD.decode_parity(tiny_hybrid, ex, max_ex=10)           # asked 10, only 3 present
    assert r["n_examples"] == 3


def test_decode_parity_positions_match_answer_span(tiny_hybrid, eval_examples):
    """answer-span mask is positions >= prompt_len-1 over T-1 next-token slots: n=3 ex, T=40, plen=30
    → each ex contributes (39 - 29) = 10 positions → 30 total."""
    ex = eval_examples(n=3, T=40, plen=30)
    r = CD.decode_parity(tiny_hybrid, ex)
    assert r["n_positions"] == 3 * (39 - (30 - 1))


def test_decode_parity_graceful_without_run_ref(eval_examples):
    """A model lacking run_ref (the pure-sequential path) returns None agreement + a note — no crash."""
    class _NoRef:
        pass

    r = CD.decode_parity(_NoRef(), eval_examples())
    assert r["argmax_agreement"] is None
    assert r["logit_max_err"] is None
    assert "note" in r and "no run_ref" in r["note"]


def test_decode_parity_skip_does_not_touch_examples(eval_examples):
    """The graceful skip returns BEFORE any forward, so it tolerates malformed examples."""
    class _NoRef:
        pass

    r = CD.decode_parity(_NoRef(), [{"garbage": True}])
    assert r["argmax_agreement"] is None


def test_decode_parity_env_default_n(tiny_hybrid, eval_examples, monkeypatch):
    """With max_ex=None the cap comes from DECODE_PARITY_N (default 8)."""
    monkeypatch.setenv("DECODE_PARITY_N", "2")
    ex = eval_examples(n=6)
    r = CD.decode_parity(tiny_hybrid, ex)                      # no max_ex → reads env
    assert r["n_examples"] == 2


def test_decode_parity_no_answer_span_is_nan(tiny_hybrid, eval_examples):
    """If NO example has an answer span (prompt_len >= T), tot=0 → agreement is nan (documented edge)."""
    import math
    ex = eval_examples(n=2, T=20, plen=40)                     # plen-1=39 > T-1=19 → mask all-False
    r = CD.decode_parity(tiny_hybrid, ex)
    assert r["n_positions"] == 0
    assert math.isnan(r["argmax_agreement"])


# ---------------------------------------------------------------------------
# (4) frozen eval-set persist round-trip (atomic save + os.replace)
# ---------------------------------------------------------------------------

def test_eval_set_roundtrip_byte_identical(tmp_path, eval_examples):
    """The frozen eval set must reload byte-identical input_ids across the self-healing relaunch loop."""
    E = {"E1": eval_examples(n=3), "E2": eval_examples(n=3), "E3": eval_examples(n=3)}
    path = str(tmp_path / "eval_set.pt")
    tmp = path + ".tmp"
    torch.save(E, tmp)
    os.replace(tmp, path)                                     # the module's atomic-freeze pattern
    E2 = torch.load(path, weights_only=False)
    assert list(E2.keys()) == ["E1", "E2", "E3"]
    for m in ("E1", "E2", "E3"):
        assert len(E2[m]) == len(E[m])
        for a, b in zip(E[m], E2[m]):
            assert torch.equal(a["input_ids"], b["input_ids"])
            assert a["id"] == b["id"]
            assert a["prompt_len"] == b["prompt_len"]


def test_eval_set_roundtrip_no_tmp_residue(tmp_path, eval_examples):
    E = {"E1": eval_examples(n=2)}
    path = tmp_path / "eval_set.pt"
    tmp = str(path) + ".tmp"
    torch.save(E, tmp)
    os.replace(tmp, str(path))
    assert path.exists()
    assert not os.path.exists(tmp)


# ---------------------------------------------------------------------------
# (5) _content_fp-style content hash stability
# ---------------------------------------------------------------------------

def _content_fp(items):
    """Mirror of the module's in-main _content_fp (sha256 over input_ids bytes)."""
    h = hashlib.sha256()
    for it in items:
        h.update(it["input_ids"].cpu().numpy().tobytes())
    return h.hexdigest()[:16]


def test_content_fp_stable_across_two_calls(eval_examples):
    """Same examples → identical hash on repeated calls (deterministic, content-only)."""
    ex = eval_examples(n=4)
    assert _content_fp(ex) == _content_fp(ex)
    assert len(_content_fp(ex)) == 16


def test_content_fp_changes_on_token_change(eval_examples):
    """A single mutated token must change the fingerprint (loud on any data drift)."""
    ex = eval_examples(n=2)
    fp1 = _content_fp(ex)
    mutated = [dict(ex[0]), ex[1]]
    ids = ex[0]["input_ids"].clone()
    ids[0] = (int(ids[0]) + 1) % 96
    mutated[0]["input_ids"] = ids
    assert _content_fp(mutated) != fp1


def test_content_fp_order_sensitive(eval_examples):
    """Concatenation order matters — a reordered eval set is a different cache key."""
    ex = eval_examples(n=3)
    assert _content_fp(ex) != _content_fp(list(reversed(ex)))


def test_content_fp_independent_of_id_and_plen(eval_examples):
    """The hash is over input_ids ONLY — changing id/prompt_len leaves it unchanged."""
    ex = eval_examples(n=2)
    fp1 = _content_fp(ex)
    relabeled = [{"id": "ZZZ", "input_ids": ex[0]["input_ids"], "prompt_len": 999},
                 {"id": "YYY", "input_ids": ex[1]["input_ids"], "prompt_len": 7}]
    assert _content_fp(relabeled) == fp1
