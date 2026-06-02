# 《宿基双生·主权第二大脑平台》 v1.0 — Outline → Code Gap Audit

> **Method.** Every named structural object in the v1.0 outline (the full "压榨 LLM" platform doc)
> was mapped to the codebase by 5 parallel read-only audit passes over both source roots
> (`BehavioralAISubstrate/Sources` + `QinaoRuntimeSDK/Sources`), prefix-agnostic (BAS / EBrain /
> Qinao) and across English / pinyin / Chinese terms. Verdicts: **BUILT** = concrete type/impl with
> real logic; **PARTIAL** = stub / incomplete / near-equivalent under another name; **MISSING** = no
> corresponding impl. Each verdict carries `file:Symbol` evidence (below). Audit date: 2026-06-02.

## Headline

| | Count | Share |
|---|---|---|
| **BUILT** | 89 | 88.1% |
| **PARTIAL** | 5 | 5.0% |
| **MISSING** | 7 | 6.9% |
| **Total objects** | 101 | |

**The v1.0 platform is ~88% built by object count.** L1–L14 squeeze objects, the 4 kernels, the 8
buses (as typed taxonomy + payloads), the 2 vaults + Snapshot Ark, the 9 席, the evolution/sovereign
objects, the surfaces, and the end-to-end turn pipeline all exist with real logic. This session's
keystone arc (LLMInvocationContract / ProcessTrace / EffortPlan / TranscriptView + the 席→contract
bridge) closed the one structural LLM-call-governance gap.

## The genuine gaps (what to actually build)

Of the 12 non-BUILT verdicts, only a few are *genuinely-absent capabilities*; the rest are
packaging/naming. Ranked by real value:

### Tier 1 — genuinely-absent capability
- **DistillationBank (蒸馏池, L13 / Phase 6)** — **MISSING.** The distillation *export* path is built
  (`BASLearningExportBundle`, `QinaoLearningExporter`, Furnace evolution seals), but the persistent
  *pool/bank* that accumulates high-quality distillation assets is absent — only a `distillTeacherRef`
  string field + a roadmap work-package. This is the capstone of the squeeze loop (§6 step 19: "高质量
  trace 进入蒸馏池"; §15 "把大模型能力榨成小器官") and connects directly to this session's `ProcessTrace`.
  *Cleanly additive / opt-in.*

### Tier 1 — composition keystone (pieces exist, not composed)
- **`brain.chat(...)` governed top-level API (§11)** — **PARTIAL.** Every piece exists
  (`runTurn` pipeline chains L6→L14; `BASEBrainTurnResult` carries surface/permit/sovereign/tickets/
  trace), but there is no single governed entry with the spec'd shape
  `brain.chat({hostId,message,effort,transcript,activeAgents,memoryScope,toolScope}) →
  {surface,effortReceipt,processTraceRef,actionPermit,sovereignStatus,updateTickets}`. The request
  type omits effort/transcript/activeAgents/scopes inputs and the result has no `effortReceipt`. This
  is the §11 developer-facing "现实接口" and would compose this session's effort/transcript/contract
  work. *Larger; touches the turn entry (behavioral) — host-deliberate.*

### Tier 2 — genuinely-absent (smaller)
- **RegretProfile (悔意剖面, L10)** — **MISSING.** L10 bearability has `MergedChoice`,
  `AgencyReservation`, `BASTradeoffLedger`, but no regret-modeling type (only "regret cost" prose in
  Qinao reader adapters). *Additive.*
- **SacrificeMap (牺牲地图, L10)** — **PARTIAL.** Only a `sacrifices: [String]` field on
  `BASTradeoffLedger`; not a structured per-stakeholder map. *Additive upgrade.*

### Tier 2 — SDK packaging (substrate type exists; not re-exported as a `Qinao*` module)
- **Qinao Effort** — MISSING in SDK (`BASEffortPlan` exists in substrate).
- **Qinao Transcript** — MISSING in SDK (`BASTranscriptView` exists in substrate).
- **Qinao Axis** — MISSING in SDK (`BASKunlun*` axis exists in substrate).
- **Qinao OldSeal** — MISSING in SDK (`BASOldSealSealingProtocol` exists in substrate).
- **Qinao Studio** — MISSING in SDK (Persona Studio lives in `BASMemory/BASAgentPersonaSDK`).
  > These are **packaging** gaps, not capability gaps: the logic is BUILT in the substrate and used
  > from demos; it is simply not surfaced under the §11 `Qinao*` module names.

### Tier 3 — naming / structuring nits (concept already present; low value)
- **ConsentMatrix** → `BASConsentLattice` (same thing, named "Lattice"). Arguably already BUILT.
- **GuardBranch** → threaded as `CandidateFrontier.guardPaths` + `case guardianBranch` enum cases; no
  standalone struct.
- **Answer (L12)** → exists as the `.answer` `BASActionPermitMode` (baseline reply); no dedicated
  surface model like the other 5 surfaces (renders as `draft`).

### Cross-slice corrections (honesty)
- The architecture pass noted "effort applied value … absent" under the Lease kernel — but
  `BASEffortPlan` **does** carry `requested`/`applied`/`overrideReason` (confirmed by two other
  passes). **Not a gap** — the note was module-scoped.
- Several SDK items are **BUILT under a different name** (Qinao Agents = `QinaoSeats`; Qinao Guard =
  `QinaoRisk`; Qinao Surfaces = `QinaoUI`; Replay/Shadow/Distill folded into `QinaoFurnace` /
  `QinaoLearningExport`). Counted BUILT.
- The **8 buses** are a typed taxonomy (`BASMotherboardBus`) + real payload structs, but share one
  generic transport (`QinaoStateGraphBus`) rather than 8 dedicated per-bus transports. This is a
  design choice, not a missing object — counted BUILT.

---

## Evidence tables

### Slice 1 — §3 architecture: 4 kernels · 8 buses · 2 vaults + ark (15 BUILT / 0 PARTIAL / 0 MISSING)

| # | Object | Verdict | Evidence (path:Symbol) | Note |
|---|--------|---------|------------------------|------|
| 1 | Sovereign Microkernel | BUILT | `BASSovereign/` (45 files); `EBrainControlPlaneCore.swift:BASSovereignWarrant/BASRollbackWrit/BASDeadStopLatch`; `BASSovereignHighConsequenceGate` | All 5 warrant types + signing + commit gate |
| 2 | Lease & Life Kernel | BUILT | `BASLeaseLife/` (8 files); `EBrainControlPlaneCore.swift:BASRunLease/BASBudgetFrame`; `BASThermalTwin` | battery/thermal/lease real |
| 3 | Neural Organ Runtime | BUILT | `BASOrchestration/EBrainL2NeuralOrganCore.swift:BASNeuralOrgan` | 12-case organ enum covers all 7 organs |
| 4 | State & Evolution Graph Kernel | BUILT | `BASMemory/BASSharedStateGraph.swift`; `MemoryEvolutionLineageCore`; `ShadowTrialCoordinator`; `BASHostVersionTree` | registry/event-sourcing/lineage/version/shadow/cascade |
| 5 | LeaseBus | BUILT | `BASRuntimeCore/BASMotherboardArchitecture.swift:BASMotherboardBus.lease` | typed payloads; generic transport |
| 6 | WorldHostBus | BUILT | `BASMotherboardBus.worldHost`; `HostConstitutionCore`, `BASWorldPriorVault` | typed bus + payload catalog |
| 7 | SituationBus | BUILT | `BASMotherboardBus.situation`; `EBrainL6SituationFieldCore.swift:BASSituationField` | situation payloads exist |
| 8 | CognitiveFrameBus | BUILT | `BASMotherboardBus.cognitiveFrame`; `BASCanonicalCognitiveFrame` | frame payloads present |
| 9 | MemoryBus | BUILT | `BASMotherboardBus.memory`; `EBrainKnowledgePlaneCore.swift:BASMemoryBundle/EpisodeArc/ConflictCluster` | atom/bundle/arc payloads |
| 10 | FrontierBus | BUILT | `BASMotherboardBus.frontier`; `EBrainL9DreamLoopCore.swift:BASCandidateFrontier` | candidate/counterfactual payloads |
| 11 | RiskPermitBus | BUILT | `BASMotherboardBus.riskPermit`; `EBrainRiskPlaneCore.swift:BASRiskField/BASActionPermit` | risk/permit payloads |
| 12 | VersionAuditBus | BUILT | `BASMotherboardBus.versionAudit`; `BASUpdateTicket`; `BASSovereignAuditLedger` (Ed25519) | version/ticket/signed-ledger |
| 13 | World Prior Vault | BUILT | `BASWorldPrior/BASWorldPriorVault.swift` (actor); `BASWorldPriorCausalTemplate` | causal/counterfactual/uncertainty real |
| 14 | Host Constitution Vault | BUILT | `BASMemory/HostConstitutionCore.swift:BASHostConstitutionVault/BASValueAxisSet/BASBoundaryVeil` | goals/values/boundary/persona/delete-freeze |
| 15 | Snapshot Ark | BUILT | `BASSovereign/BASSnapshotManager.swift`; `BASSovereignCleanRebootCoordinator` | snapshot/fold/restore real |

### Slice 2 — L1–L7 squeeze objects (20 BUILT / 1 PARTIAL / 0 MISSING)

| # | Object | Verdict | Evidence | Note |
|---|--------|---------|----------|------|
| 1 | EffortPlan | BUILT | `BASRuntimeCore/BASEffortPlan.swift:BASEffortPlan` | + budget.forLevel, override tracking |
| 2 | BudgetFrame | BUILT | `BASRuntimeCore/EBrainControlPlaneCore.swift:BASBudgetFrame` | 17-field versioned frame |
| 3 | RunLease | BUILT | `EBrainControlPlaneCore.swift:BASRunLease` | quotas, validHeads, expiry |
| 4 | causal template | BUILT | `BASWorldPrior/BASWorldPriorTypes.swift:BASWorldPriorCausalTemplate` | preconditions/effect/reversibility |
| 5 | counterfactual structure | BUILT | `BASWorldPriorCounterfactualSeeder.swift` | seeder fans ≥3 branches; no "matrix" name |
| 6 | uncertainty grammar | BUILT | `BASWorldPriorTypes.swift:BASWorldPriorEvidenceLevel` | 5-step ladder, Comparable |
| 7 | boundary prior/bedrock | BUILT | `BASWorldPriorTypes.swift:BASWorldPriorAxiom` | axiomatic tier |
| 8 | Kunlun axis view | BUILT | `BASOrchestration/BASKunlunLayerSchemas.swift:BASKunlunAxisView` | centerline priors, deviation |
| 9 | abyss unknowable reserve | BUILT | `BASWorldPrior/BASUnknownReserve.swift:BASUnknownReserve` | assertionCeiling, derive() |
| 10 | HostConstitution | BUILT | `BASMemory/HostConstitutionCore.swift:BASHostConstitution` | full struct + vault + version tree |
| 11 | HostVersion | BUILT | `EBrainKnowledgePlaneCore.swift:BASHostVersion` | versionID, changedFields, rollback |
| 12 | ConsentMatrix | **PARTIAL** | `HostConstitutionCore.swift:BASConsentLattice` | near-equiv; named "Lattice" |
| 13 | AgentPersonaSpec | BUILT | `BASMemory/BASAgentPersonaSpec.swift:BASAgentPersonaSpec` | tone/warmth/skepticism style |
| 14 | HumanAnchorProfile | BUILT | `BASOrchestration/BASHumanAnchorProfile.swift` | dignity invariants, no-exploitation |
| 15 | SituationField | BUILT | `EBrainL6SituationFieldCore.swift:BASSituationField` | 15-field schema |
| 16 | AnomalyTrace | BUILT | `BASOrchestration/BASAbyssalProtocol.swift:BASAnomalyTrace` | anomalyTypes, pressureVector |
| 17 | AxisDeviation | BUILT | `BASOrchestration/BASKunlunControlFlow.swift:BASAxisDeviation` | deviationScore, correctionHint |
| 18 | CanonicalCognitiveFrame | BUILT | `EBrainL6SituationFieldCore.swift:BASCanonicalCognitiveFrame` | facts/goals/unknowns/pressures |
| 19 | JadeMirrorDraft | BUILT | `BASOrchestration/BASKunlunHostIntegrity.swift:BASJadeMirrorDraft` | cleanReflection, disclosures |
| 20 | UnknownSet | BUILT | `EBrainL7MirrorBladeDecomposeCore.swift:BASUnknownSet` | missing facts/roles/constraints |
| 21 | NarrativeDistortionMap | BUILT | `BASOrchestration/BASNarrativeDistortionMap.swift` | per-subject distortions |

### Slice 3 — L8–L11 squeeze objects (19 BUILT / 2 PARTIAL / 1 MISSING)

| # | Object | Verdict | Evidence | Note |
|---|--------|---------|----------|------|
| 1 | hot/warm/cold tiers | BUILT | `EBrainKnowledgePlaneCore.swift:BASMemoryTemperatureBand`; `BASMemoryTieringReconciler.swift` | enum + reconciler |
| 2 | EpisodeArc | BUILT | `EBrainKnowledgePlaneCore.swift:BASMemoryEpisodeArc` | arc state, threads |
| 3 | ConflictCluster | BUILT | `EBrainKnowledgePlaneCore.swift:BASMemoryConflictCluster` | conflictType, severity |
| 4 | YaochiSanctum | BUILT | `BASOrchestration/BASKunlunProtocol.swift:BASYaochiSanctumEntry` | 6 sanctum classes, reveal |
| 5 | OldSeal | BUILT | `BASMemory/BASSealEnvelope.swift:BASOldSealSealingProtocol` | seal envelope + helpers |
| 6 | CandidateFrontier | BUILT | `EBrainL9DreamLoopCore.swift:BASCandidateFrontier` | dominance order, paths |
| 7 | CounterfactualBranch | BUILT | `EBrainL9DreamLoopCore.swift:BASCounterfactualBranch` | altered condition, shift |
| 8 | AscentBranch | BUILT | `BASKunlunControlFlow.swift:BASAscentBranch` | gate sequence, dignity invariant |
| 9 | ReturnPath | BUILT | `BASKunlunControlFlow.swift:BASReturnPath` | dignityPreserved, nextSafeStep |
| 10 | GuardBranch | **PARTIAL** | `CandidateFrontier.guardPaths`; `case guardianBranch` | fields/enum-cases, no struct |
| 11 | EvidenceDebt | BUILT | `EBrainL9DreamLoopCore.swift:BASEvidenceDebt` | missingEvidence, debtWeight |
| 12 | UncertaintyLedger | BUILT | `EBrainL9DreamLoopCore.swift:BASUncertaintyLedger` | unknowns, weak predictions |
| 13 | MergedChoice | BUILT | `EBrainL10TribunalCore.swift:BASMergedChoice` | veto, tradeoff, agency |
| 14 | SacrificeMap | **PARTIAL** | `EBrainL10TribunalCore.swift:BASTradeoffLedger.sacrifices` | only `[String]` field |
| 15 | RegretProfile | **MISSING** | (none; "regret cost" prose in Qinao adapters) | no type |
| 16 | AgencyReservation | BUILT | `EBrainL10TribunalCore.swift:BASAgencyReservation` | mode enum + reasons |
| 17 | risk vector / RiskField | BUILT | `EBrainRiskPlaneCore.swift:BASRiskField` (+`BASHazardVector`) | hazard/harm/GSI composite |
| 18 | reversibility | BUILT | `EBrainRiskPlaneCore.swift:BASReversibilityProfile` | rollbackCost, draftSafe |
| 19 | GSI | BUILT | `EBrainRiskPlaneCore.swift:BASGSITrace`; `computeGSI` | trace + real logic |
| 20 | AbyssPressure | BUILT | `BASAbyssalProtocol.swift:BASAbyssalPressure` | 7-dim pressure vector |
| 21 | HeavenGatePermit | BUILT | `BASKunlunProtocol.swift:BASHeavenGatePermit` | gate class, required seals |
| 22 | ActionPermit | BUILT | `EBrainRiskPlaneCore.swift:BASActionPermit` | mode, ceilings, membrane |

### Slice 4 — L12–L14 squeeze objects (21 BUILT / 1 PARTIAL / 1 MISSING)

| # | Object | Verdict | Evidence | Note |
|---|--------|---------|----------|------|
| 1 | Answer | **PARTIAL** | `EBrainRiskPlaneCore.swift:BASActionPermitMode.answer` | permit mode; no surface type |
| 2 | ComparePanel | BUILT | `QinaoUI/QinaoComparePanel.swift` | model + SwiftUI view |
| 3 | DraftShell | BUILT | `QinaoUI/QinaoDraftShell.swift` | score/reversibility buckets |
| 4 | DelayPacket | BUILT | `QinaoUI/QinaoDelayPacket.swift` | reason codes, retry clamp |
| 5 | BoundaryScript | BUILT | `QinaoUI/QinaoBoundaryScript.swift` | headline/body/redirections |
| 6 | LocalOnlyAction | BUILT | `QinaoUI/QinaoLocalOnlySheet.swift` | `.localOnly` permit wired |
| 7 | SilentStub | BUILT | `QinaoUI/QinaoSilentStub.swift` | refusal receipt + audit ref |
| 8 | ProcessView / ProcessTrace | BUILT | `BASOrgan/BASProcessTrace.swift:BASProcessTrace` | per-call trace, no raw body |
| 9 | TranscriptView (6 modes) | BUILT | `BASOrgan/BASTranscriptView.swift:BASTranscriptMode` | all 6 modes render |
| 10 | UpdateTicket | BUILT | `EBrainObservationPlaneCore.swift:BASUpdateTicket` | + lifecycle + SQLite |
| 11 | RuleCandidate | BUILT | `EBrainKnowledgePlaneCore.swift:BASRuleCandidate` | scope, conflicts, approval |
| 12 | HostChangeCandidate | BUILT | `HostConstitutionCore.swift:BASHostChangeCandidate` | delta, cooldown, rollback |
| 13 | BiasRecord | BUILT | `EBrainEvolutionGovernanceCore.swift:BASBiasRecord` | type, severity, layers |
| 14 | GuardTemplateCandidate | BUILT | `EBrainEvolutionGovernanceCore.swift:BASGuardTemplateCandidate` | scene, script refs |
| 15 | ShadowTrialRecord | BUILT | `EBrainEvolutionGovernanceCore.swift:BASShadowTrialRecord` | + state machine + SQL |
| 16 | LearningExportBundle | BUILT | `EBrainEvolutionGovernanceCore.swift:BASLearningExportBundle` | scrubbed/privacy flags |
| 17 | DistillationBank | **MISSING** | (only `distillTeacherRef` field; roadmap WP15) | no bank/pool type or storage |
| 18 | SovereignWarrant | BUILT | `EBrainControlPlaneCore.swift:BASSovereignWarrant` | + chain validator + audit |
| 19 | OldSeal | BUILT | `BASMemory/BASSealEnvelope.swift:BASOldSealSealingProtocol` | seal + access policy |
| 20 | LineageCut | BUILT | `BASSovereignAuditLedger.swift:lineageCut(request:)` | + fixpoint cascade |
| 21 | RollbackWrit | BUILT | `EBrainControlPlaneCore.swift:BASRollbackWrit` | + `.rollback` verdict |
| 22 | CleanReboot | BUILT | `BASSovereignCleanRebootCoordinator.swift` (actor) | reboot plans, restore |
| 23 | DeadStopLatch | BUILT | `EBrainControlPlaneCore.swift:BASDeadStopLatch` | + `.deadStop` verdict |

### Slice 5 — §5 contract · §6 pipeline · §11 SDK (14 BUILT / 1 PARTIAL / 5 MISSING)

| # | Item | Verdict | Evidence | Note |
|---|------|---------|----------|------|
| 1 | LLMInvocationContract | BUILT | `BASOrgan/BASLLMInvocationContract.swift` | purpose/forbidden/schema/verifier/sovereign + digest |
| 2 | ProcessTrace | BUILT | `BASOrgan/BASProcessTrace.swift` | accepted/rejected factories; no raw body |
| 3 | EffortPlan (req/applied/override) | BUILT | `BASRuntimeCore/BASEffortPlan.swift` | + budget expansion; granted/downgraded |
| 4 | TranscriptView (6 modes) | BUILT | `BASOrgan/BASTranscriptView.swift` | all six modes |
| 5 | End-to-end turn pipeline | BUILT | `BASHostKit/EBrainRuntimeCoordinator+RunTurn.swift:runTurn` | chains L6→L14 in order |
| 6 | Qinao Runtime | BUILT | `QinaoRuntime/QinaoRuntime.swift:QinaoRuntime` | actor; turn entry + audit halt |
| 7 | Qinao Agents | BUILT | `QinaoSeats/QinaoAgentProposal.swift:QinaoSeat` | agents-as-seats; renamed |
| 8 | Qinao Effort | **MISSING** | (`BASEffortPlan` in substrate only) | no SDK effort module |
| 9 | Qinao Transcript | **MISSING** | (`BASTranscriptView` in substrate only) | no SDK transcript module |
| 10 | Qinao Memory | BUILT | `QinaoMemory/QinaoMemory.swift:QinaoMemory` | admit/retrieve + export gate |
| 11 | Qinao Guard | BUILT | `QinaoRisk/QinaoRisk.swift:QinaoRiskGate` | risk gate; renamed |
| 12 | Qinao Sovereign | BUILT | `QinaoSovereign/QinaoSovereign.swift:QinaoSovereignControlPlane` | warrant/audit/rollback |
| 13 | Qinao Surfaces | BUILT | `QinaoUI/*` | the 5 surfaces; renamed dir |
| 14 | Qinao Replay | BUILT | `QinaoHost/QinaoFurnace.swift:replay` | ledger replay |
| 15 | Qinao Shadow | BUILT | `QinaoRuntime/QinaoSovereignShadowTrialBridge.swift` | shadow-trial bridge |
| 16 | Qinao Distill | BUILT | `QinaoMemory/QinaoLearningExport.swift:QinaoLearningExporter` | export gate + seals |
| 17 | Qinao Axis | **MISSING** | (`BASKunlun*` in substrate only) | no SDK axis module |
| 18 | Qinao OldSeal | **MISSING** | (`BASOldSealSealingProtocol` in substrate only) | no SDK oldseal module |
| 19 | Qinao Studio | **MISSING** | (Persona Studio in `BASMemory/BASAgentPersonaSDK`) | substrate-side, not SDK |
| 20 | `brain.chat(...)` governed entry | **PARTIAL** | `EBrainTurnResult.swift:BASEBrainTurnResult`; `QinaoRuntime.sendSession` | pieces exist; not composed to spec shape |

---

## Recommended build order (genuine gaps only)

1. **DistillationBank** (Tier 1, MISSING capability) — additive/opt-in; completes the squeeze loop;
   ingests high-quality `ProcessTrace` / `LearningExportBundle` into a persistent, sovereign-safe pool.
2. **`brain.chat(...)` composition** (Tier 1, PARTIAL) — the §11 developer keystone; composes
   effort + transcript + contract + agents + permit + sovereign + tickets into one governed entry.
   Behavioral → host-deliberate, ADR-014 posture.
3. **RegretProfile + SacrificeMap upgrade** (Tier 2) — completes L10 bearability objects.
4. **SDK packaging** (Tier 2) — re-export `Qinao Effort / Transcript / Axis / OldSeal / Studio` over
   the existing substrate types (packaging, not new capability).
5. **Naming nits** (Tier 3, optional) — `ConsentMatrix` alias, `GuardBranch` struct, `Answer` surface.

> Everything above is additive. Per ADR-014 the new objects default OFF / byte-equal-off, and any
> behavioral composition (#2) is the host's deliberate install step.
