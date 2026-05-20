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

- `BehavioralAISubstrate/` — the core library。 Swift Package Manager-based,
  no Xcode project required。 Builds + tests via `swift build` and
  `swift test`。
- `SampleHost/` — minimal app demonstrating the substrate's public surface。
- `QinaoRuntimeSDK/` — substrate's runtime SDK packaging。

## Build

```bash
cd BehavioralAISubstrate
swift build      # clean SPM build,no Xcode required
swift test       # ~13k tests,~85s sweep
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
