# Mamba-3 cloud-distill regression suite

349 CPU-only pytest tests pinning the **audited invariants** of the distill pipeline so a regression can't silently make
the paid cloud run unsafe. No network, no Granite, no coreai — heavy/real-Granite paths stay in the standalone e2e.

## Run

```bash
# pytest is a dev-only dependency (not used by the standalone Tools/test_*.py scripts). Install once:
VIRTUAL_ENV=~/.venvs/coreai-cv uv pip install pytest

cd BehavioralAISubstrate
~/.venvs/coreai-cv/bin/python -m pytest Tools/tests -q
```

## Modules (what each pins)

| file | invariants |
|---|---|
| `test_raft_data.py` | gold-survival truncation, to_ids/masking, E1/E2/E3 semantics + no answer-leak, determinism, masked_ce, eval_nll skip |
| `test_curriculum.py` | competence pacing, **true-quantile gate** (uniform + skewed), sample/replay, raft staging, state_dict rng round-trip, bad-input guards |
| `test_eval_gates.py` | the **8 claim_card gates** incl. the **anti-parrot `context_use`** guarantee, measured-teacher fail-closed, device_parity None-coercion, masked fidelity, text EM/F1, subset guard, contamination |
| `test_kd_loss.py` | top-K KD (renorm/temperature/gather/shape-assert), kd_kl, full-K≈full-KD, gradient flow, `_sanitize` |
| `test_forward_consistency.py` | run_twin ≡ step_ref (Mamba + hybrid + MLA), **LEAN_MLP one-source-of-truth** |
| `test_cloud_integration.py` | build_cache fingerprint drift (incl. data hash), save_ckpt round-trip, decode_parity, eval_set freeze |
| `test_deploy_carry.py` | resolve_ckpt arch/layers/vocab/mla/config guards, assert-not-missing |
| `test_hybrid_mla.py` | MLA placement, prefill→decode DUET handoff, generate, MLA step≡forward_seq |
