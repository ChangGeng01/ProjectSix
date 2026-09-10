# BehavioralAISubstrate

A private,Apple-only substrate for behavior-aware host apps。 14-layer
electronic brain (L1-L14) with measurement-driven Swift + Rust + SQL +
Metal hybrid implementation。

**Current release:[`v0.56.0`](https://github.com/ChangGeng01/ProjectSix/releases/tag/v0.56.0)** — first
semver tag,covers chapters 七百二 → 七百五十七 (MATURATION ARC SEAL +
post-severance polish + SDK readiness docs)。 See
`BehavioralAISubstrate/CHANGELOG.md` for full release notes,
`BehavioralAISubstrate/VERSIONING.md` for stability policy,
`BehavioralAISubstrate/MIGRATING.md` for upgrade steps,
`BehavioralAISubstrate/INTEGRATION.md` for 5-step host-adoption walkthrough。

## Repo layout (post-severance,post-reconstitution)

```
BehavioralAISubstrate/    ← canonical substrate (14-layer 电子脑)
                            CHANGELOG / VERSIONING / MIGRATING / INTEGRATION docs at root
QinaoRuntimeSDK/          ← substrate-related runtime SDK
SampleHost/               ← standalone SPM iOS package — reference host
└── Tests/SampleHostTests/  ← SPM-canonical test layout (relocated 2026-05-21)
bench-baselines/          ← performance baselines (sha256,hmac,audit ledger,etc.)
docs/                     ← substrate documentation
scripts/                  ← repo-wide tooling (XCFramework build,LOC counter,
                            redaction + boundary checks)
Archive/
├── Legacy/               ← severed Before iOS app + retired quality-gate scripts
│                          + retired quality-gate docs (preserved per
│                          「依旧 不删除 只 comment」 discipline)
└── (BehavioralAISubstrate/Archive/Deactivated/ — substrate-internal
    deactivations from chapter 七百五十二 + 七百五十七 cleanup arcs)
```

## What this repo holds now

### Current development vs preserved historical tooling

Current development uses ordinary Git commits, the existing draft PR, necessary
tests/CI and code review. The active work is **App/runtime persistence and
recovery**, not another system for persisting the development process. See the
[current DS3 readiness plan](docs/superpowers/plans/2026-09-09-qinao-ds3-readiness-solo.md)
and [user decisions](docs/superpowers/specs/2026-09-10-qinao-approved-decisions.md).
DS3 requires separate approval and has not started.

| Area | Current role |
| --- | --- |
| `.github/workflows/test.yml`, build/boundary/regression tests | Active ordinary engineering checks; not merge authorization |
| `scripts/qinao_convergence_audit.py`, `run_qinao_managed_convergence.py`, `run_qinao_wave_admission.py`, `prepare_qinao_v2_wave_candidate.py`, `check_qinao_owner_ledger.py`, `qinao_a02_provisional_design_edge.py`, `qinao_a03_design_source_identity.py`, their tests/fixtures and old plans | Preserved historical development-workflow tooling; not part of current development admission or an App persistence deliverable |
| App/runtime storage, recovery and audit modules; artifact-mesh device recovery tooling; original DS1/DS2 evidence | Retained necessary product/evidence work; not retired with development controllers |

Historical files remain at their original paths to preserve links and recorded
identities, along with their tests and design rationale for possible reuse.
"Historical" means not currently required, not disposable or proven useless.
No history or old implementation is deleted. Their continued
presence does not make the old workflow a current prerequisite; do not run it as
part of ordinary development. Current product claims require actual runtime and
reopen tests, not saved development records.

- `BehavioralAISubstrate/` — the core library。 Swift Package Manager-based,
  no Xcode project required。 Builds via `swift build`; headless validation
  uses `swift test --disable-swift-testing` because monolithic `swift test`
  still hits a SwiftPM swift-testing helper SIGBUS in headless macOS.
- `SampleHost/` — minimal app demonstrating the substrate's public surface。
- `QinaoRuntimeSDK/` — substrate's runtime SDK packaging。

## Build

```bash
cd BehavioralAISubstrate
swift build                         # clean SPM build,no Xcode required
swift test --disable-swift-testing  # headless XCTest gate
```

## 14-layer substrate (L1-L14)

| Layer | Concern | Module |
|---|---|---|
| L1 | Lease lifecycle | BASLeaseLife |
| L2 | Neural organ math kernels | BASOrgan |
| L3 | Thought-fold observations | BASRuntimeCore |
| L4-L7 | Runtime + observation aggregation | BASRuntimeCore |
| L8 | Memory (atoms,vectors,KV cache) | BASMemory |
| L9 | Dream loop batch-scoring | BASRuntimeCore |
| L10 | Tri-self court (id/ego/superego derive) | BASOrchestration |
| L11 | Risk plane + permit escalation | BASPolicy |
| L12 | Audit projections | BASRuntimeCore |
| L13 | Evolution furnace (nursery + shadow trial + seal + retraction) | BASHostKit |
| L14 | Sovereign verdict + ledger | BASSovereign |

## Hybrid implementation (Swift / Rust / SQL / Metal)

- **Swift** — façade,Apple-glue,public API,host integration
- **Rust** — measured hot paths (L14 verdict engine = 13.84× win,
  L14 chain seal = 1.24× win,batched cosine,quantization primitives,
  etc.) shipped via XCFramework
- **SQL** — typed persistence schemas (audit_entries,segments,
  risk_observations,permit_escalation,replay_log_events,
  knowledge_graph_nodes,etc.) wired via SPM BuildToolPlugin
- **Metal** — kernel libraries for SSM scan,batched cosine,etc.

## Production-default Rust flips (3 active)

- **L14 chain seal** — `useRoutedSeal: true` (1.24× measured)
- **L14 verdict engine** — `useRoutedVerdictLevel: true` (13.84× measured)
- **L11 SQL persistence** — `BASRiskObservationLedger.sharedStorage`
  (production seam wired)

## History

This branch severed the legacy "Before" iOS app — see
`Archive/Legacy/README.md.archive-notice` for the move details and
the original Before-era README at `Archive/Legacy/README.md`。

Internal substrate development history (chapters 七百二 →
七百五十七) lives in `BehavioralAISubstrate/BRANCH_SUMMARY.md`。
