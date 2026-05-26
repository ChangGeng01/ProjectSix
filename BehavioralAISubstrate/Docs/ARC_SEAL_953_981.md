# Agent Fabric Arc Seal — chapters 953-981

**Arc**: Agent Fabric (chapters 953-981 + 5 USER-PASS sub-chapters)
**Start**: ch 953 / M3470 (Phase 0 ch1)
**End**: ch 981 / M3610 (Phase 8 close + ARC SEAL)
**Status**: SEALED at ch 981 — substrate-side complete, device-verification PENDING per phase smoke docs

---

## Arc-level claims

1. **Single sovereign host** preserved across 29 chapters. The 7 Root Laws are enforced at type-system level (Single-Writer-Per-Domain via `BASSharedStateGraph` + per-agent `writeDomains`/`forbiddenDomains`) AND at runtime via the graph actor's `writeObject(...)` check.
2. **20 agents wired** (9 core + 7 watcher + 4 reference skill — see Phase 5 + Phase 6).
3. **Every external surface** (MCP + A2A) routes through a dedicated gateway that degrades external code to proposal-only, tool-domain-scoped refs (see Phase 7).
4. **Persona overlay** lives ATOP the fabric via the formula `P_effective = Clamp(P_role ⊕ P_user ⊕ P_host, Risk, Sovereign)` (see Phase 4).
5. **3 N-pass review cycles** (956.11 + 964.5 + 969.5) caught **35+ real bugs** before production — including the CG1 sovereignty crisis at ch 969.5 that would have rejected the system's own sovereign agents at runtime.

## Arc trajectory (8 phases, 29 chapters)

| Phase | Chapters | Theme | Tests added |
|---|---|---|---|
| **0** | 953-955 + 956.5 | Prototype (schemas + state graph + merge engine) | 65 |
| **1** | 956-959 + 956.6-956.11 | 4-seat closure + Rust FFI + SQL + coordinator wire | 110 |
| **2** | 960-962 | Memory + Critic seats + evidence-debt + fuzz | 52 |
| **3** | 963-965 + 964.5 | Host/Sovereign/Evolution (.alignmentField + .sovereignVerdict + .evolutionProposal) | 67 |
| **4** | 966-969 + 969.5 | Persona Studio (resolver + Risk + Sovereign + SDK + forbidden detector) | 92 |
| **5** | 970-972 | 7 watcher agents + L14 audit aggregator + adversarial fuzz | 62 |
| **6** | 973-975 | SDK productization (skill agents + API stability + DeviceTestApp sample) | 46 |
| **7** | 976-978 | MCP + A2A external interop (HIGH risk — sovereign-locked external surface) | 56 |
| **8** | 979-981 | End-side perf (latent spine + hot/cold tier + speculative + zero-copy) + arc seal | 31 |
| **TOTAL** | **29** | | **~580+ tests** |

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
correction + ch 981.7 ARC FINALIZE Item 5:**10 prefixes are
reserved** for the agent fabric subsystem (no other substrate
code may emit `signalRefs` starting with these prefixes)。 **6 are
in-use today + 4 are future-allocation** (reserved but not yet
emitted by any source path)。

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

All Phase 1-7 audit signals absorb into the existing `SovereignAuditEntry.signalRefs [String]` array — **zero schema change** per ch 953 reuse pattern。 The 3 future-allocation prefixes are **reserved in this document** so future host-app integration cannot accidentally use them for another purpose — they will be filled in when the coordinator wires Phase 1-5 emission paths to the audit ledger (separate workstream beyond arc 953-981)。

## Performance posture (end of Phase 8)

Per plan PHASE 8 goals:
- **Latent spine** (ch 979): N agents share one encode pass → expected 5-10× speedup on compare mode (3+ active agents)
- **Hot/cold tier** (ch 980): 4 hot + 5 cold + 4 sealed core agents → ~50ms cold-start cost amortized per turn instead of 450ms (9× hot-start)
- **Speculative prefetch** (ch 981): Memory recall + compare shell + guard templates fire concurrently with L6/L7 — net 30-50ms saved on med+ risk turns
- **Zero-copy state bus** (ch 981): refs not strings → bounded allocation per turn

**Cumulative perf budget**: ≤ +15% vs ch 952.6 baseline (per plan). Substrate-side: 0 regression measured at simulator level. Device-side: verified by operator running Phase 8 close 2-hour smoke per `Docs/PHASE_8_CLOSE_SMOKE.md`.

## Test totals

| Source | Tests | Failures |
|---|---|---|
| Phase 0 (953-955 + 956.5) | 65 | 0 |
| Phase 1 (956-959 + 956.6-956.11) | 110 | 0 |
| Phase 2 (960-962) | 52 | 0 |
| Phase 3 (963-965 + 964.5) | 67 | 0 |
| Phase 4 (966-969 + 969.5) | 92 | 0 |
| Phase 5 (970-972) | 62 | 0 |
| Phase 6 (973-975) | 46 | 0 |
| Phase 7 (976-978) | 56 | 0 |
| Phase 8 (979-981) | 31 | 0 |
| **Total arc** | **580+** | **0** |
| Full sweep (substrate-wide) | 14,150+ | 0 |

All tests pass with 0 unexpected failures. 113 fuzz-skipped tests via `BAS_FUZZ_RUNTIME_SKIP=1` env var (legitimate skips for long-running fuzz that the operator runs out-of-band per ch 952.x discipline).

## N-pass review track record

| Round | Sub-ch | Findings | Real bugs caught |
|---|---|---|---|
| 1 | 956.11 | 4C + 6H + MED + test backfill | 10+ |
| 2 | 964.5 | 2C + 4H + 7 doc + 6 gaps | 15+ |
| 3 | 969.5 | 2C + 1 GAP + 4H + 1 DH + 2 DM | 10+ |
| **Total** | **3 rounds** | | **35+ real bugs** |

Each round caught at least 1 CRITICAL bug that production-shape tests had missed. The CG1 sovereignty crisis fix at ch 969.5 alone would have rejected the substrate's own sovereign agents at runtime.

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

## Push status

As of arc seal at ch 981, the local branch `phase-5-chapter-952-iphone-air-10hr-validation` is 8+ commits ahead of `origin/phase-5-chapter-952-iphone-air-10hr-validation`. Push pending explicit user authorization per the standing instruction across this entire arc.

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

## Arc seal declaration

By the discipline this arc has held to (red-line 7 additive-only, byte-equality when fabric unconfigured, 3-agent N-pass review every ~8 chapters with 35+ real bugs caught, pure-fn + slim-DTO seat layer for 8 of 9 core agents, sovereign-locked external surfaces), the Agent Fabric arc 953-981 is hereby **SUBSTRATE-SEALED** at the simulator level.

Device-verification (the 2-hour iPhone Air 3-mode smoke) is documented but pending operator execution. When operator runs the smoke and all 3 modes pass per the criteria above, this arc is **DEVICE-SEALED**.

Next arc (post-981) scope:
- Round-table mode (Phase 9+) — N-way agent collaboration
- Sovereign warrant infrastructure (Phase 9+) — formal collaborator-tier upgrade chain
- App-suspension state persistence (Phase 9+) — persona + watcher hint cold restart
- Host-app integration (separate workstream) — env-var gate, DeviceTestApp wiring, Qinao runtime adoption
