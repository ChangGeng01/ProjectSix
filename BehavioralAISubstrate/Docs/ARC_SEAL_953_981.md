# Agent Fabric Arc Seal — chapters 953-995.7

**Arc**: Agent Fabric (chapters 953-995.7 + 15+ USER-PASS / META-REVIEW + Cross-Module Integration sub-chapters)
**Start**: ch 953 / M3470 (Phase 0 ch1)
**End**: ch 995.7 / M3680.7 (Round-13 META-REVIEW cascade fixes)
**Substrate-island sealed**: ch 981 / M3610 (Phase 8 close + initial ARC SEAL)
**Cross-module arc closed**: ch 990 / M3655 (8 cross-module gaps from ch 982.5 META-REVIEW)
**Host integration shipped**: ch 995 / M3680 (BASAgentFabricHostPipeline + DeviceTestApp)
**Status**: SUBSTRATE-COMPLETE — fabric is internally consistent + cross-module-wired + host-pipeline-shipped at the simulator level. Device-verification (3-mode 2hr iPhone Air smoke per `Docs/PHASE_8_CLOSE_SMOKE.md`) PENDING operator. 13 N-pass review rounds complete with 100+ real bugs caught. Latest substrate-wide test count: **14,459 / 0 failures**.

---

## Arc-level claims (scope-honest)

1. **Single sovereign host** preserved across 29 chapters. The 7 Root Laws are enforced at type-system level (Single-Writer-Per-Domain via `BASSharedStateGraph` + per-agent `writeDomains`/`forbiddenDomains`) AND at runtime via the graph actor's `writeObject(...)` check — **within the fabric island**. The fabric does NOT yet read from or write into the host's existing L5 `BASHostConstitution` / L11 `BASRiskServicing` / L10 `BASMLTriSelfService` — see "Cross-module integration gap" section.
2. **20 agents wired internally** (9 core + 7 watcher + 4 reference skill — see Phase 5 + Phase 6). All 20 dispatch through `BASAgentTurnDispatcher.dispatch(...)` end-to-end; none are wired through `EBrainRuntimeCoordinator`.
3. **Every external surface** (MCP + A2A) routes through a dedicated gateway that degrades external code to proposal-only, tool-domain-scoped refs (see Phase 7). The gateway does NOT yet import `BASPolicy.BASActionPermit` — the cross-module integration is documented as forward work.
4. **Persona overlay** lives ATOP the fabric via the formula `P_effective = Clamp(P_role ⊕ P_user ⊕ P_host, Risk, Sovereign)` (see Phase 4). The Risk + Sovereign clamp is a fabric-internal pure-fn; it does not delegate to the live host's risk/sovereign services.
5. **9 N-pass review cycles** (956.11 + 964.5 + 969.5 + 981.5 + 981.6 + 981.7 + 981.8 + 981.9 + 982 + 982.5 META-REVIEW) caught **70+ real bugs** before production — including the CG1 sovereignty crisis at ch 969.5 that would have rejected the system's own sovereign agents at runtime, the SIGBUS root cause at ch 981.9, the U+001F malformed-JSON regression at ch 982.5, and the cross-module parallel-island finding at ch 982.5 META-REVIEW.

## Arc trajectory (8 phases + META-REVIEW, 29+10 sub-chapters)

| Phase | Chapters | Theme | Tests added (actual, per ch 982.5 audit) |
|---|---|---|---|
| **0** | 953-955 + 956.5 | Prototype (schemas + state graph + merge engine) | 49 |
| **1** | 956-959 + 956.6-956.11 | 4-seat closure + Rust FFI + SQL + coordinator wire | 128 |
| **2** | 960-962 | Memory + Critic seats + evidence-debt + fuzz | 52 |
| **3** | 963-965 + 964.5 | Host/Sovereign/Evolution (.alignmentField + .sovereignVerdict + .evolutionProposal) | 68 |
| **4** | 966-969 + 969.5 | Persona Studio (resolver + Risk + Sovereign + SDK + forbidden detector) | 93 |
| **5** | 970-972 | 7 watcher agents + L14 audit aggregator + adversarial fuzz | 62 |
| **6** | 973-975 | SDK productization (skill agents + API stability + DeviceTestApp sample) | 46 |
| **7** | 976-978 | MCP + A2A external interop (HIGH risk — sovereign-locked external surface) | 56 |
| **8** | 979-981 + 981.5-981.9 + 982 + 982.5 | End-side perf + ARC SEAL + 6 N-pass-review sub-chapters | 109 |
| **TOTAL** | **29 + 10 sub** | | **663 tests** |

> **chapter 九百八十二.5 META-REVIEW doc-fix**:earlier versions of this table claimed Phase 0=65 / Phase 1=110 / Phase 8=31 / TOTAL=580+。 Reality at sub-chapter cascade close is Phase 0=49 (over-stated 33%) / Phase 1=128 (under-stated 16%) / Phase 8=109 (under-stated 71% — the 981.5-981.9+982+982.5 sub-chapter tests were never aggregated into the Phase 8 row) / TOTAL=663 (under-stated 14%)。 The drift accumulated as each cascade fix landed without updating this aggregate table — caught only at the META-REVIEW pass。

## Final invariants list (sealed at ch 981)

### Root Laws (7) — enforced every chapter

1. **单宿主** — single host constitution (L5 `BASHostConstitution`)
2. **单世界** — single L4 world prior
3. **单状态图** — single typed `BASSharedStateGraph` actor + Single-Writer-Per-Domain
4. **单主权** — L14 `BASSovereignVerdictEngine` issues all final verdicts
5. **单提交口** — all writes through one commit endpoint
6. **多角色** — N agents, but role ≠ sovereign split
7. **可回放** — every observation/proposal/delta/reject reason replayable

### Domain-level invariants

| Domain | Single writer | Forbidden for external/skill |
|---|---|---|
| `.situationField` | Scout | ✓ |
| `.canonicalCognitiveFrame` | L7 thoughtFold | ✓ |
| `.memoryBundle` | Memory agent (L8) | ✓ |
| `.candidateFrontier` | Planner agent (L9) | ✓ |
| `.critiqueField` | Critic agent | ✓ |
| `.alignmentField` | HostAlignment agent | ✓ |
| `.riskField` | Risk agent (L11) | ✓ |
| `.actionPermit` | Risk + L11 windGate | ✓ |
| `.renderFrame` | Surface agent (L12) | ✓ |
| `.sovereignVerdict` | L14 SovereignSentinel | ✓ |
| `.hostVersion` | L5 + L14 (L13 proposes only) | ✓ |
| `.evolutionProposal` | EvolutionShadow (NEVER effective same turn) | ✓ |

12 domains total. All 12 are forbidden for skill agents (ch 973) AND for external agents (ch 977). Sovereign-locked subset (`.hostVersion` / `.sovereignVerdict` / `.actionPermit` / `.evolutionProposal`) is forbidden for ALL non-sovereign agents.

### Pipeline invariants (verified by 580+ tests)

- **Phase 4 monotonic raise** — Risk floor can ONLY RAISE skepticism / guard / directness / comparison; ONLY CAP challenge / creativity (ch 967)
- **Phase 4 sovereign clamp** — LOW-tier sealed-default OR force-default UNLESS sovereign warrant grants specific field (ch 968)
- **Phase 4 forbidden detector** — 4 patterns (shame / gaslight / absolute-paternal / controlling) catch both INPUT and OUTPUT, except LOW-tier output exempt (ch 969 + 969.5 CG1)
- **Phase 5 watcher discipline** — read-only (writeDomains empty), pattern-based (no ML), 4 severity levels (info/watch/alert/veto), sanctum-leak ALWAYS .veto (ch 970-972)
- **Phase 6 skill agent discipline** — writeDomains empty, sovereign-locked domains forbidden (ch 973)
- **Phase 7 external discipline** — external agents degraded to proposal-only with ALL 12 domains forbidden, identity-mismatch caught FIRST in defense-in-depth, unattested/collaborator-claim downgraded non-optionally (ch 977)

### Reserved signalRefs prefixes (L14 absorption channel)

Per ch 981.5 USER-PASS-7 DH3 doc-fix + ch 981.6 USER-PASS-8 D1
correction + ch 981.7 ARC FINALIZE Item 5 + ch 990 Cross-Module
Integration Arc Gap 2 close:**11 prefixes are reserved** for the
agent fabric subsystem (no other substrate code may emit
`signalRefs` starting with these prefixes)。 **7 are in-use today
+ 4 are future-allocation** (reserved but not yet emitted by any
source path)。 The 11th `agentMCP.permit:` was added at ch 990
for MCP-invocation permit validation outcomes — see closure
summary table below。

| Prefix | Phase | Status | Carries |
|---|---|---|---|
| `agentFabric.activated:` | 1+ | future-allocation | per-seat activation (when coordinator wires) |
| `agentFabric.merged:` | 0 | future-allocation | merge engine outcomes (when coordinator emits) |
| `agentPersona.applied:` | 4 | future-allocation | persona SDK applications (when coordinator emits) |
| `agentPersona.clamped:` | 4 | future-allocation | Risk + Sovereign clamp outcomes (when emitted) |
| `agentWatcher.flag:` | 5 | in-use | per-hint at .alert/.veto |
| `agentWatcher.count:` | 5 | in-use | per-severity totals |
| `agentExternal.proposal:` | 7 | in-use | external proposal landed |
| `agentExternal.tier:` | 7 | in-use | effective sandbox tier |
| `agentExternal.trust:` | 7 | in-use | trust score after scans |
| `agentExternal.warrant:` | 8 (ch 981.7) | in-use | sovereign warrant validation outcome |
| `agentMCP.permit:` | Cross-Module Arc (ch 990) | in-use | MCP-invocation permit validation outcome (`granted` / `rejected:reason=...`) |

All Phase 1-7 audit signals absorb into the existing `SovereignAuditEntry.signalRefs [String]` array — **zero schema change** per ch 953 reuse pattern。 The 3 future-allocation prefixes are **reserved in this document** so future host-app integration cannot accidentally use them for another purpose — they will be filled in when the coordinator wires Phase 1-5 emission paths to the audit ledger (separate workstream beyond arc 953-981)。

## Performance posture (end of Phase 8)

Per plan PHASE 8 goals:
- **Latent spine** (ch 979): N agents share one encode pass → expected 5-10× speedup on compare mode (3+ active agents)
- **Hot/cold tier** (ch 980): 4 hot + 5 cold + 4 sealed core agents → ~50ms cold-start cost amortized per turn instead of 450ms (9× hot-start)
- **Speculative prefetch** (ch 981): Memory recall + compare shell + guard templates fire concurrently with L6/L7 — net 30-50ms saved on med+ risk turns
- **Zero-copy state bus** (ch 981): refs not strings → bounded allocation per turn

**Cumulative perf budget**: ≤ +15% vs ch 952.6 baseline (per plan). Substrate-side: 0 regression measured at simulator level. Device-side: verified by operator running Phase 8 close 2-hour smoke per `Docs/PHASE_8_CLOSE_SMOKE.md`.

## Test totals (per ch 982.5 META-REVIEW actual count)

| Source | Tests (actual) | Tests (originally claimed) | Failures |
|---|---|---|---|
| Phase 0 (953-955 + 956.5) | 49 | 65 (over +33%) | 0 |
| Phase 1 (956-959 + 956.6-956.11) | 128 | 110 (under -16%) | 0 |
| Phase 2 (960-962) | 52 | 52 ✓ | 0 |
| Phase 3 (963-965 + 964.5) | 68 | 67 (±1) | 0 |
| Phase 4 (966-969 + 969.5) | 93 | 92 (±1) | 0 |
| Phase 5 (970-972) | 62 | 62 ✓ | 0 |
| Phase 6 (973-975) | 46 | 46 ✓ | 0 |
| Phase 7 (976-978) | 56 | 56 ✓ | 0 |
| Phase 8 (979-981 + 981.5-981.9 + 982 + 982.5) | 109 | 31 (under -71% — sub-chapter cascade tests never aggregated) | 0 |
| **Total arc** | **663** | **580+ (under -14%)** | **0** |
| Full sweep (substrate-wide) | 14,150+ | — | 0 |

All tests pass with 0 unexpected failures. 113+ fuzz-skipped tests via `BAS_FUZZ_RUNTIME_SKIP=1` env var (legitimate skips for long-running fuzz that the operator runs out-of-band per ch 952.x discipline).

The drift in the right column shows how doc-staleness accumulates during a long arc — every cascade sub-chapter shipped tests but the aggregate table was never re-totaled。 ch 982.5 META-REVIEW recomputed each row from `grep -c "func test"` against the actual files in `Tests/BehavioralAISubstrateTests/`。

## N-pass review track record (updated at ch 982.5 META-REVIEW)

| Round | Sub-ch | Findings | Real bugs caught |
|---|---|---|---|
| 1 | 956.11 | 4C + 6H + MED + test backfill | 10+ |
| 2 | 964.5 | 2C + 4H + 7 doc + 6 gaps | 15+ |
| 3 | 969.5 | 2C + 1 GAP + 4H + 1 DH + 2 DM | 10+ |
| 4 | 981.5 | 3C + 2 deferred-item closes (3 + 7) | 8+ |
| 5 | 981.6 | 4H + 4M fix-of-fix bugs in ch 981.5 | 8+ |
| 6 | 981.7 (ARC FINALIZE) | 3 deferred-item closes (1 + 5 + 8) + 4H + 4 test gaps | 8+ |
| 7 | 981.8 | round-6 review caught 4H + 4 test gaps in 981.5/981.7 | 8+ |
| 8 | 981.9 | round-7 + SIGBUS root cause + test count + 9-seat migration | 6+ |
| 9 | 982 | round-8 doc-staleness only (cascade pressure shifting) | 3+ |
| **10 (META)** | **982.5** | **2C (U+001F malformed-JSON + cross-module parallel-island) + multiple H + doc-drift correction** | **7+** |
| **Total** | **10 rounds** | | **70+ real bugs** |

Each round caught at least 1 CRITICAL bug that production-shape tests had missed. The CG1 sovereignty crisis fix at ch 969.5 alone would have rejected the substrate's own sovereign agents at runtime. The ch 982.5 META-REVIEW catch is the most architecturally significant — the parallel-island finding documents that the arc shipped 663 internally-consistent tests for an internally-consistent fabric that is NOT YET WIRED into the production substrate's existing service plane (see next section)。

## Forward-looking deferred items

Per ch 981.5 USER-PASS-7 + ch 981.7 ARC FINALIZE,**5 of the original
8 deferred items have been CLOSED**。 3 items remain explicit
won't-ship (out-of-scope / forbidden / host-side):

1. ~~**Round-table mode**~~ — **CLOSED at ch 981.7** by `BASAgentRoundTable.swift` shipping a scaffold (proposal + vote + quorum + dissent + consensus pure-fn)。 Dispatcher integration deferred to Phase 9+ as a future arc;the scaffold itself is fully functional for callers who want round-table coordination today。 10 regression tests pin the contract。
2. **Persona marketplace / sharing** — out of substrate scope (host-app feature)。 **(won't-ship — out of scope)**
3. ~~**App-suspension state persistence**~~ — **CLOSED at ch 981.5** by `BASAgentFabricColdRestart.swift` + `BASAgentFabricSessionSnapshot` Codable record + `BASColdRestartValidationResult` + `validate(...)` pure-fn with 5 validation rules (SDK version + age + forbidden persona drop + warrant corruption + orphan check)。 12 regression tests pin the contract (incl. future-date catch added by ch 981.6)。
4. **Multi-tenant sovereign** — explicitly forbidden by Root Law 1 (single host)。 **(won't-ship — forbidden)**
5. ~~**Sovereign warrant infrastructure for `.collaborator` external tier**~~ — **CLOSED at ch 981.7** by `BASSovereignWarrantChain.swift` + 3-stage chain (host-root + per-agent + expiration) + `BASSovereignWarrantValidator.validate(...)` + `BASExternalAgentGateway.effectiveTierWithWarrant(...)` extension。 10 regression tests pin the contract (incl. identity-mismatch + expired + nil-warrant fallback)。
6. **Env-var gate wiring** (`BAS_PERSONA_ENABLED` / `BAS_WATCHERS_ENABLED` / `BAS_TRANSCRIPT_MODE`) — documented in Phase 4-7 smoke docs but never wired to `run-iphone-air-10hr.sh` or dispatcher。 **(won't-ship from substrate — host-app integration responsibility)**
7. ~~**Fuzz determinism for ch 967 risk tests**~~ — **CLOSED at ch 981.5** (deterministic LCG)。 **Re-enhanced at ch 981.6** with state-advancement between draws so pSkep + floor are truly independent samples (not affine-linked)。
8. ~~**8 file-private `escapeForJSON*` extension consolidation**~~ — **CLOSED at ch 981.7** by `BASAgentFabricJSONEscape.swift` shipping the shared `escape(_:)` helper。 Per red-line 7 + ch 943 cascade discipline,seats are NOT migrated to the shared helper in this commit — migration is a separate per-seat task with byte-equal-output verification。 6 regression tests pin the shared helper's contract (matches the byte-equal output of all 9 existing extensions)。

### Closed items (5 of 8)

| Item | Sub-ch | Module / Tests |
|---|---|---|
| 3 | 981.5 | `BASAgentFabricColdRestart.swift` + 11+1 tests |
| 7 | 981.5 + 981.6 | Deterministic LCG + state-advance + meta-test |
| 1 | 981.7 | `BASAgentRoundTable.swift` (scaffold) + 10 tests |
| 5 | 981.7 | `BASSovereignWarrantChain.swift` + gateway extension + 10 tests |
| 8 | 981.7 | `BASAgentFabricJSONEscape.swift` + 6 tests |

### Won't-ship items (3 of 8)

| Item | Reason |
|---|---|
| 2 | Persona marketplace — host-app feature,not substrate |
| 4 | Multi-tenant sovereign — forbidden by Root Law 1 |
| 6 | Env-var gate wiring — host-app integration workstream |

### Cross-arc deferred concern (caught at ch 982 Round 8 review)

**BASSovereignEd25519Signing canonical-bytes separator class issue**:
`Sources/BASSovereign/BASSovereignEd25519Signing.swift:119-121`
joins `ruleIDs`, `signalRefs`, `actionRefs` with `","` separator
when building the canonical bytes for ed25519 signing。 If any
of those array entries CONTAINS a `,` (legitimately,since they
include caller-supplied opaque strings like `agentExternal.
proposal:<externalID>:...`),the signing function produces an
ambiguous representation — two different signalRef lists could
yield the same canonical bytes,enabling signature collision。

This is the **same class of issue** as ch 981.9 C1 (which
solved it for `agentExternal.warrant:granted:...` by switching
to U+001F)。 However:
- It's in **BASSovereign module** (not Agent Fabric arc scope)
- The Agent Fabric arc's `agentExternal.*` audit refs could now
  PROBABLY contain `,` since `externalAgentID` is caller-supplied
  opaque
- Round 8 flagged this as a CROSS-ARC concern,not as a regression

**Recommended scope**:separate arc (Phase 9+ or BASSovereign
hardening pass) to:
1. Audit all canonical-byte serialization paths in BASSovereign
2. Either escape character-class-restricted separators or use
   U+001F throughout
3. Add input validation at BASExternalAgentRef.init / similar
   boundaries that REJECTS `,` in opaque IDs

**Risk assessment**:to actually exploit,attacker would need
(a) ability to control externalAgentID + (b) a target L14 audit
entry to collide with。 Per ch 977 external agents are tightly
sandboxed,so attacker control of externalAgentID requires
host-side compromise already。 Not an immediate security crisis
but worth a dedicated fix arc。

**Status**:DEFERRED to post-arc Phase 9+ BASSovereign hardening。
Documented here so it doesn't slip through the cracks。

## Cross-module integration arc (ch 983-993 — ALL 8 GAPS CLOSED + N-pass review + residual sweep + host-integration convenience + cross-arc separator hardening)

The ch 982.5 META-REVIEW Reviewer-4 surfaced 8 specific cross-module integration gaps documented in the next section。 Per user direction「全面 开发」at the META-REVIEW close,a follow-up arc 983-990 landed adapters closing every one of those gaps。 This section pins the closure status before the original META-REVIEW disclosure remains as the rationale + design history。

### Closure summary (ch 983-992, 11 chapters, ALL ✅ + N-pass review + residual sweep)

| Gap | Chapter | Adapter | Tests | Discipline pin |
|---|---|---|---|---|
| **7** Warrant DEAD-LETTER → audit ledger | ch 983 | `BASSovereignWarrantAuditBridge` (in BASOrchestration) | 8 | U+001F sentinel preserved verbatim through bridge; idempotent on duplicate auditID |
| **6** TraceLog → BASEventLogStorage | ch 984 | `BASAgentTraceLogEventLogBridge` (write-through + flush) | 9 | Idempotent flush via eventID uniqueness; payload U+001F preserved; Int64.max nanos saturates |
| **8** Adapter 4-seat → 9-seat | ch 985 | `BASAgentFabricAdapters.turnInput` + coordinator `runAgentFabricObservation` extended | 5 | Default-nil preserves prior 4-seat caller compat byte-equal |
| **1** HostConstitution read | ch 986 | `BASAgentFabricAdapters.hostAlignmentInput(from:candidates:styleStrictnessOverride:)` | 9 | Sorted union of valueAxes.axes + boundaryVeil.hardNoGo; defensive clamp; determinism |
| **3** RiskCard → RiskInput | ch 987 | `BASAgentFabricAdapters.enrichRiskInput(from:baseRiskInput:)` | 9 | Monotonic raise (ch 967) — never lowers pressure or manipulation signals |
| **4** TriSelf → CriticInput | ch 988 | `BASAgentFabricAdapters.enrichCriticInput(from:baseCriticInput:)` | 8 | Monotonic raise; vetoed candidates excluded; all-vetoed forces 1.0 worst-case-honesty |
| **5** CandidateFrontier projection | ch 989 | `BASAgentFabricAdapters.candidateFrontierProjection(from:)` | 11 | Deterministic sort; band classification (>= 0.7 reversible, < 0.3 guard); order-invariant |
| **2** MCP gateway → BASActionPermit | ch 990 | `BASAgentFabricAdapters.validateMCPInvocation(_:against:)` | 11 + 3 (ch 991.5) | 4-rule defense-in-depth; blocklist > allowlist priority; reserved `agentMCP.permit:` prefix; **CRITICAL-1 fix ch 991.5: deny-scope set extended to {denied, none, blocked} after Round-9 caught that production code uses "none"/"blocked", never "denied"** |
| (coordinator E2E composition) | ch 991 | `BASChapter991CoordinatorIntegrationE2ETests` | 3 | proves 9-seat pipeline composes through coordinator with all 5 enrichment adapters + warrant audit + trace flush + frontier projection + MCP permit validation |
| (N-pass review fix-of-fix) | ch 991.5 | adapters + tests + docs | 5 (added) | Round-9 cascade pattern: CRITICAL-1 (deny-scope set) + HIGH-1 (enrichCriticInput semantic inversion fixed to use fraction-vetoed) + GAP-1/2/7 mutation-safety pins |
| (residual findings sweep) | ch 992 | adapters + tests | 12 (added) | **「全面 剩余 一次性 解决掉」**: MED-1 (enrichRiskInput merged-result clamp) + MED-2 (clamp test strengthening) + MED-3 (`includeSoftAxes` flag for 5-field BoundaryVeil union) + GAP-3 (concurrent recordEvent race) + GAP-4 (override clamp) + GAP-5 (negative-base clamp) + GAP-6 (U+001F in agentID/deltaID actions) + GAP-8 (empty sessionID synthesize) + GAP-9 (diversity exact 0.0) + GAP-10 (delayedPaths empty pin) + GAP-11 (source field per-entry correctness) |
| (host-integration + cross-arc hardening) | ch 993 | adapter + gate + canonical-bytes | 12 (added) | **「全部 剩余 部分 一次性 解决掉」**: A. `BASAgentFabricFullTurnAdapter.run(...)` collapses 14-step host pipeline to 1 call (closes UX gap) + B. `BASAgentFabricGate.activationFromEnvironment(...)` env-var probing (substrate-side of deferred item #6) + C. **CRITICAL cross-arc separator hardening** — `basSovereignAuditCanonicalBytes(...)` schema-gated U+001F/U+001E hardening for `1.1.0+` entries (closes ch 982 Round-8 cross-arc concern) + warrant bridge defaults to `1.1.0` hardened format |
| **TOTAL** | **12 chapters** | **9 adapters / bridges + E2E + 2 fix-batches + host-integration + cross-arc hardening** | **103 tests** | **all CRITICAL + HIGH + MED + LOW invariants pinned + 9th N-pass review complete + residual findings closed + cross-arc concern closed + host-integration UX shipped** |

### What changed at the substrate level

Before ch 983-990:
- Fabric was a parallel island with 663 internally-consistent tests but no path into the production substrate's service plane
- 7 of 8 cross-module gaps had ZERO wire-up code
- 1 of 8 (Gap 8 — adapter) had a 4-seat stub but the 5 optional seats were unreachable

After ch 983-990:
- 8 additive adapters / bridges live in BASOrchestration (where module-graph permits importing both BASMemory + BASPolicy + BASRuntimeCore + BASSovereign types)
- Host adapters can now build complete cross-module DTOs:
  ```
  // Example: 9-seat turn through coordinator
  let permit: BASActionPermit = riskService.gateAction(...)
  let card: BASRiskCard = riskService.calibrateRisk(...)
  let triScores: [BASTriSelfScore] = triSelfService.mergeChoice(...)
  let hostInput = BASAgentFabricAdapters.hostAlignmentInput(
      from: hostConstitution, candidates: [...])
  let riskInput = BASAgentFabricAdapters.enrichRiskInput(
      from: card,
      baseRiskInput: BASAgentFabricAdapters.riskInput(...))
  let criticInput = BASAgentFabricAdapters.enrichCriticInput(
      from: triScores,
      baseCriticInput: BASAgentFabricAdapters.criticInput(...))
  let result = await coordinator.runAgentFabricObservation(
      turnID: ..., decomposeFrame: ..., candidatePaths: ...,
      memory: ..., critic: criticInput,
      hostAlignment: hostInput, sovereignSentinel: ...,
      evolutionShadow: ...)
  let warrantResult = BASSovereignWarrantValidator.validate(...)
  try await BASSovereignWarrantAuditBridge.appendToLedger(
      validationResult: warrantResult, sessionID: ..., turnID: ...,
      externalAgentID: ..., ledger: sovereignAuditLedger)
  try await traceLogEventBridge.flush(forTurn: ...)
  ```
- Per Root Law 7 (可回放),every adapter is pure-fn deterministic — re-running any adapter on the same input produces byte-equal output
- Per Root Law 4 (单主权) + ch 967 monotonic-raise discipline,enrichment adapters NEVER lower risk / concern signals
- Per red-line 7 additive-only,EVERY new adapter is opt-in; the 14,329 pre-Phase-0 tests still pass byte-equal because no existing call site is modified

### What still requires host integration

The substrate-side adapters are wired。 What the host application must still do:

1. **Build the live service inputs** — pull `BASActionPermit` from `riskService.gateAction(...)`, `BASRiskCard` from `riskService.calibrateRisk(...)`, `BASTriSelfScore[]` from `triSelfService.mergeChoice(...)`, etc。 The adapters do not do the upstream service calls (that's host's per-turn pipeline)。
2. **Call the adapters in the right order** — Risk + TriSelf enrichment happens BEFORE dispatch; Warrant audit + TraceLog flush happens AFTER dispatch。
3. **Configure the fabric runtime** — set `coordinator.agentFabric = BASAgentFabricRuntime(...)` with the 9-seat roster + shared state graph + optional trace log。
4. **Run device-side smoke** — the ch 952.6 baseline doesn't exercise these adapter paths; host needs to add fabric-on smoke iterations per `Docs/PHASE_8_CLOSE_SMOKE.md`。

These are host-side responsibilities per ADR-014 OPT-IN + plan section 9 design intent。 The substrate ships the library; the host wires the pipeline。 But unlike before ch 983, EVERY connection point now exists and is tested。

### Honest scope statement (revised at ch 992 — full closure)

| Surface | Status | Verified by |
|---|---|---|
| Fabric-island (dispatcher + seats + merge + audit) | ✅ SEALED | 663 + ch 982.5 = 663 tests at 0 failures |
| **Cross-module adapter layer** (8 bridges/adapters) | ✅ **SHIPPED** (ch 983-990) | **70 new regression tests at 0 failures** |
| Host-side wiring (caller builds DTOs + calls adapters) | ⏸️ HOST RESPONSIBILITY | Adapter contracts pinned; host's call-site is host-app concern |
| Device verification (3-mode 2hr iPhone Air smoke) | ⏸️ PENDING OPERATOR | Substrate-side ch 952.6 baseline unchanged |

The fabric is no longer a parallel island。 It is now a wired substrate adapter layer awaiting host integration + operator device verification。 The transition is one full arc smaller in scope than the cross-arc effort I had originally estimated at META-REVIEW close (multi-month vs single-session) because each gap turned out to be cleanly tractable as a pure-fn adapter in BASOrchestration with no protocol changes required upstream。

## Cross-module integration gap (ch 982.5 META-REVIEW CRITICAL honest disclosure — KEPT FOR HISTORY)

The ch 982.5 META-REVIEW Reviewer-4 (cross-module integration) pass produced the most architecturally significant finding of the arc:**the entire fabric ships as a parallel island that is internally consistent at the simulator level but is not yet wired into the production substrate's existing service plane**。 This section documents the gap honestly so a future arc can close it deliberately rather than discovering it as a runtime surprise。

### What "parallel island" means concretely

The Agent Fabric arc 953-982.5 built a self-contained subsystem:13 seat files + 9 supporting modules + 663 tests,all dispatching through `BASAgentTurnDispatcher.dispatch(...)`。 But the existing pre-Phase-0 production substrate has its OWN service plane (`EBrainRuntimeCoordinator` + `BASRiskServicing` + `BASMLTriSelfService` + `BASRoutedEventLogStorage` + `BASSovereignAuditLedger` + `BASHostConstitution`)。 The fabric does NOT yet read from or write into ANY of these — it is a wholly disjoint code path that compiles + tests cleanly but is unreachable from any pre-Phase-0 caller。

This was **by design** per plan red-line 7 (additive only,byte-equal when fabric unconfigured) + ADR-014 OPT-IN — the integration work was always intended as a separate workstream。 But earlier versions of this ARC_SEAL doc framed the arc as "substrate-side complete",which over-claims。 The fabric is **fabric-island complete**;the substrate integration is the next arc。

### Specific integration gaps (Reviewer-4 enumerated)

| # | What's NOT wired | What it would take to wire |
|---|---|---|
| 1 | `BASHostAlignmentSeat.hostConstraintsRef` is a free-form string parameter — it does not actually READ from the live `BASHostConstitution.styleGenome` / `routineSkeleton` / `valueAxes` | Coordinator adapter that converts the live `BASHostConstitution` into `BASHostAlignmentInput.hostBoundaryAxes` before dispatch |
| 2 | `BASMCPCapabilityGateway` validates inputs but does NOT call into `BASPolicy.BASActionPermit` to enforce permits — the permit check is documented but unimported | Add `import BASPolicy` + wire MCP-tool calls through `BASActionPermit.grant(...)` per ch 953 design |
| 3 | `BASRiskSeat` is a pure-function that emits `.riskField` deltas — it does NOT delegate to the host's live `BASRiskServicing` (used by `EBrainRuntimeCoordinator`) | Coordinator adapter that calls `riskService.evaluate(...)` and feeds the result into `BASRiskInput` before dispatch |
| 4 | Fabric dispatch does NOT invoke `BASMLTriSelfService` (the 三我庭 id/ego/superego) — Critic seat is a thin pure-fn,not a wrapper around `triSelfService.guard` per ch 953 plan | Coordinator adapter calls `triSelfService.guard(...)` and feeds the result into `BASCriticSeatInput` before dispatch — must invoke BEFORE triSelf per ch 956 plan |
| 5 | Fabric `.candidateFrontier` deltas are disjoint from the host's existing `BASCandidateFrontierSummary` (built by `loopService.proposePaths`) | Coordinator adapter builds `BASPlannerCandidate[]` from live `BASCandidatePath[]`,then writes accepted-deltas back to the live frontier |
| 6 | `BASAgentTraceLog` is an in-memory actor — it does NOT use `BASRoutedEventLogStorage` (the existing event-sourced replay log) per ch 953 plan section 8 | Add a write-through path that fans every trace event into `BASRoutedEventLogStorage` |
| 7 | `BASSovereignWarrantValidator.validate(...)` emits `agentExternal.warrant:granted:host-root=<id>\u{001F}per-agent=<id>` audit refs (ch 981.7 + 982 U+001F fix) — but NO in-substrate consumer pipes these refs into `BASSovereignAuditLedger`,so the carefully-fixed refs are currently **DEAD-LETTER** | Coordinator + `EBrainL14SovereignVerdictPlane` adapter that intercepts `effectiveTierWithWarrant` audit refs and appends them to the ledger via `signalRefs:`|
| 8 | **Zero integration tests through `EBrainRuntimeCoordinator`** — all 663 tests dispatch directly through `BASAgentTurnDispatcher` | A new test class `BASChapter9XXCoordinatorIntegrationTests` that drives a coordinator-end turn through the fabric and asserts the fabric outputs reach the existing service plane outputs |

### Why each gap was not closed in arc 953-982.5

The arc plan (`/Users/changgeng/.claude/plans/wild-rolling-meerkat.md`) explicitly scoped the fabric as a multi-phase initiative where Phase 9+ (post-arc) would handle host-app integration。 Within the 8-phase scope of 953-981,every coordinator-side wire was deferred to "post-arc"。 This was deliberate:

- It preserved red-line 7 (byte-equal when fabric unconfigured) — the fabric cannot regress existing code if existing code does not call it。
- It bounded the per-phase risk to substrate-side additions only。
- It allowed device-verification (ch 952.6 baseline) to remain valid throughout the arc because no per-turn path changed。

But the over-claim is that "substrate-side complete" suggested the fabric is one operator-action away from production。 Realistically,closing the 8 integration gaps above is **its own multi-chapter arc** — likely Phase 9+ ch 983-990 or similar。

### Honest scope statement

The Agent Fabric arc 953-982.5 produced:

- **Fabric-island**:internally-consistent multi-seat dispatcher with 663 tests at 0 failures。 ✅ **COMPLETE**
- **Cross-module integration**:wiring the fabric into `EBrainRuntimeCoordinator` + existing L5/L7/L8/L9/L10/L11/L14 services。 ❌ **NOT STARTED** — Phase 9+ scope
- **Device verification**:3-mode 2hr iPhone Air smoke per `Docs/PHASE_8_CLOSE_SMOKE.md`。 ⏸️ **PENDING OPERATOR** — substrate-side passes ch 952.6 baseline unchanged

### Forward path

A future arc 983-99X should:

1. Land coordinator-side adapters for the 8 gaps in priority order (Gap 7 — warrant audit refs to ledger — is the highest-value since it closes a DEAD-LETTER condition shipped at ch 981.7;Gap 4 — triSelf wiring — is most architecturally risky)
2. Add `BASChapter98XCoordinatorIntegrationTests` that asserts EACH gap's adapter produces the documented behavior
3. Run the 3-mode device smoke documented in `Docs/PHASE_8_CLOSE_SMOKE.md` with the integration adapters live
4. Update this section's table from ❌ → ✅ as each gap closes

Until that arc lands,**the fabric is correctly described as a parallel island that compiles + tests + is dispatch-callable but is not part of the live per-turn path**。 Operators who want to invoke the fabric today MUST do so through a custom harness that calls `BASAgentTurnDispatcher.dispatch(...)` directly (per the env-var caveat in `Docs/PHASE_8_CLOSE_SMOKE.md`)。

## Push status

As of ch 995.7, the active branch is `phase-5-chapter-981-agent-fabric-arc-seal`, pushed continuously through each chapter close. HEAD reflects all ch 953-995.7 work + 13 N-pass review cascade rounds。 Original ch 981 push status referred to a now-superseded branch `phase-5-chapter-952-iphone-air-10hr-validation`。

## Arc seal verification (operator procedure)

Per plan, the arc seal is finalized via a 3-mode 2-hour iPhone Air real-device run:

```bash
# Mode 1: Fabric OFF (baseline = ch 952.6 behavior)
BAS_AGENT_FABRIC=disabled MAX_SEC=7200 \
    BAS_DEVICE_LOG_DIR=/tmp/ch981-fabric-off \
    bash scripts/run-iphone-air-10hr.sh

# Mode 2: Fabric ON, all 20 agents
BAS_AGENT_FABRIC=enabled BAS_AGENT_TIER=all MAX_SEC=7200 \
    BAS_DEVICE_LOG_DIR=/tmp/ch981-fabric-all \
    bash scripts/run-iphone-air-10hr.sh

# Mode 3: Fabric ON, compare-mode 5 active agents
BAS_AGENT_FABRIC=enabled BAS_TRANSCRIPT_MODE=compareSelected \
    BAS_ACTIVE_AGENTS=Planner,Critic,Memory,Risk,Surface MAX_SEC=7200 \
    BAS_DEVICE_LOG_DIR=/tmp/ch981-fabric-compare \
    bash scripts/run-iphone-air-10hr.sh

# Trend analysis
python3 scripts/analyze-ch952-trend.py /tmp/ch981-fabric-all
python3 scripts/analyze-ch952-trend.py /tmp/ch981-fabric-compare
```

Pass criteria for arc seal:
- 0 failures across all 3 modes
- 0 single-writer-per-domain violations
- Cumulative perf delta ≤ +15% vs ch 952.6 baseline
- All 20 agents respect sovereign-lock invariants
- All 4 sealed-LOW agents force-default through full chain

> **Note**: Per the env-var deferred item above, the 3-mode operator procedure requires the BAS_AGENT_FABRIC env var to be wired into `scripts/run-iphone-air-10hr.sh` and the dispatcher. As of ch 981, this wiring is documented as future host-app integration work. Operator may either (a) wait for that integration, OR (b) run the baseline smoke as-is + manually exercise the 20-agent set through a test harness that calls `BASAgentTurnDispatcher.dispatch(...)` directly.

## Arc seal declaration (scope-honest)

By the discipline this arc has held to (red-line 7 additive-only, byte-equality when fabric unconfigured, **9 N-pass review cycles + 1 META-REVIEW + 8 cross-module integration chapters** spanning ch 953-990 with **70+ real bugs** caught + **all 8 META-REVIEW cross-module gaps closed**, pure-fn + slim-DTO seat layer for 9 of 9 core agents, sovereign-locked external surfaces, monotonic-raise discipline across every cross-module enrichment adapter), the Agent Fabric arc 953-990 is hereby **SUBSTRATE-COMPLETE** at the simulator level (transitioning from "FABRIC-ISLAND-SEALED" at ch 982.5 to "SUBSTRATE-COMPLETE" at ch 990).

Honest framing at ch 990:

| Surface | Status | Verified by |
|---|---|---|
| Fabric-island (dispatcher + seats + merge + audit) | ✅ SEALED | 663 tests at 0 failures |
| **Cross-module adapter layer** (8 bridges) | ✅ **SHIPPED** | 70 new tests at 0 failures (see ch 983-990 closure table above) |
| Host-side wiring (caller builds DTOs + calls adapters) | ⏸️ HOST RESPONSIBILITY | adapter contracts pinned; host's call-site is host-app concern per ADR-014 OPT-IN |
| Device verification (3-mode 2hr iPhone Air smoke) | ⏸️ PENDING OPERATOR | substrate-wide ch 952.6 baseline unchanged through arc |

When operator runs the smoke and all 3 modes pass per the criteria above, the fabric-island portion is **DEVICE-CONFIRMED-NEUTRAL** (proves it doesn't regress existing code, NOT that it's wired through coordinator yet)。

Next arc (post-982.5) scope:
- **Cross-module integration arc** — close the 8 parallel-island gaps documented above (estimated ch 983-990+, multi-month effort)
- Round-table mode integration into the live dispatcher (scaffold shipped at ch 981.7;dispatcher integration deferred)
- App-suspension state persistence runtime integration (validator shipped at ch 981.5;runtime read-back deferred)
- Host-app surfaces (env-var gate, DeviceTestApp wiring, Qinao runtime adoption) — separate workstream
- BASSovereign canonical-bytes hardening (cross-arc concern flagged at ch 982 Round 8 — separator class issue in ed25519 signing)

The fabric-island is **the necessary first half** of "agents in the host"。 The cross-module integration arc is the second half。 Both halves together produce a production-shippable multi-agent runtime;the first half alone produces a tested library。
