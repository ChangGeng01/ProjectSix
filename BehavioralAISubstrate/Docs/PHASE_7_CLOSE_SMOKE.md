# Phase 7 Close — iPhone Air External Interop Smoke (Operator Procedure)

**Arc**: Agent Fabric 953-981
**Phase**: 7 — MCP + A2A external interop (ch 976-978)
**Status**: simulator-verified host-level CI passes (cumulative arc 580+ tests, 0 failures) — device-verification PENDING
**Operator**: maintainer with physical iPhone Air + Gemma 4 E2B + mock external agent

---

## What this smoke validates

Per plan PHASE 7 close requirements (HIGH-risk phase):

1. MCP-tool invocations route through Capability Gateway → all 4 pipeline steps execute (envelope / scope / scan / seal)
2. A2A external agents NEVER directly write to ANY state graph domain (verified by sweep across all 12 domains)
3. External proposals route through `BASExternalAgentGateway.submit(...)` and emerge as `BASAgentSpec` with `writeDomains: []` + full sovereign-locked forbidden set
4. Sanctum-leak attacks via external payload → rejected
5. Tool injection (3+ markers) → rejected
6. Unattested external agent → downgraded to `.observer`
7. Declared-collaborator without sovereign warrant → downgraded to `.advisor`
8. Cross-phase invariants hold (Phase 4 monotonic raise + Phase 5 watcher detection + Phase 6 skill sovereign-lock all still pass under Phase 7 surface)

## Pre-flight

```bash
cd /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate
swift build
swift test --filter "BASChapter97[678]" 2>&1 | grep "Executed [0-9]"
```

Expected: clean build, all 3 Phase 7 chapters pass (20 + 26 + 10 = 56 tests).

## End-to-end on iPhone Air

> **Pre-condition**: real Gemma 4 E2B model on iPhone Air via MLX (already validated by ch 952.7) + mock external agent (operator writes a 50-line A2A mock client that simulates one of: clean proposal / injection attack / sanctum-leak attempt / impersonation attempt).

### Phase 7 close 1-hour smoke

```bash
# Same wrapper used in Phase 5-6 baseline:
MAX_SEC=3600 \
    BAS_DEVICE_LOG_DIR=/tmp/ch978-phase7-close \
    bash scripts/run-iphone-air-10hr.sh
```

The smoke wrapper exercises the existing 14-layer substrate. Phase 7's new surfaces (MCP gateway + external gateway) are invoked via the operator's mock external client script (run alongside the smoke).

### Adversarial smoke scenarios (operator runs each in turn)

For each scenario, log to `/tmp/ch978-phase7-close/scenario-NN.json`:

| # | Scenario | Expected outcome |
|---|---|---|
| 1 | Clean MCP read of small file | accepted, trust=1.0 |
| 2 | Clean external advisory note (.advisor tier) | accepted, audit refs emitted |
| 3 | MCP returns prompt with 1 injection marker | accepted at trust=0.5, watcher hint surfaced |
| 4 | MCP returns coordinated 3+ marker injection | REJECTED with `mcp.injection-detected` |
| 5 | External agent attempts sanctum-leak payload | REJECTED with `external.sanctum-leak-detected` |
| 6 | External agent impersonation (mismatched ID) | REJECTED with `external.identity-mismatch` |
| 7 | Declared-collaborator without attestation tries memoryAnchor | REJECTED with `external.tier-violation` |
| 8 | External agent tries to write `.hostVersion` directly via degraded spec | REJECTED at graph actor (sovereign-locked) |
| 9 | Multi-vector attack (#5 + #6 + #7 combined) | REJECTED at FIRST check (identity mismatch) |
| 10 | External tool-hint for an mcp.server NOT in allowedToolDomains | REJECTED with `external.tool-scope-violation` |

Pass criteria: all 10 scenarios produce the expected outcome. Any scenario where a REJECTED case is accepted is a CRITICAL sovereign breach → file ch 978.5 USER-PASS-7 fix immediately.

## Trend analysis

```bash
python3 scripts/analyze-ch952-trend.py /tmp/ch978-phase7-close
```

Pass criteria:

| Metric | Pass threshold | Status |
|---|---|---|
| Total failures | 0 | active |
| MCP rejection rate (coordinated-injection inputs) | 100% | active (ch 976 + ch 978 tests confirm 100%) |
| External agent direct-write attempts | 0 successful | active (ch 977 + ch 978 sweep over 12 domains confirms 100% blocked) |
| Sanctum-leak detection rate (external) | 100% | active (ch 977 SanctumLeakWatcher reuse confirms 100%) |
| Phase 7 cumulative perf delta vs ch 952.6 baseline | ≤ +10% | active |
| Audit-ledger `agentExternal.` + `agentWatcher.` prefix compliance | 100% | active |

## Phase 7 close invariants

### Invariant 1 — External agents NEVER write to state graph

For every external `BASAgentSpec` returned by `BASExternalAgentGateway.submit(...)`, `writeDomains.isEmpty == true` AND `forbiddenDomains` contains ALL 12 state-graph domains. Verified by `testCRITICAL_ExternalCannotWriteAnyDomain` (ch 977) which sweeps all domains and asserts every write attempt is blocked at the graph actor level.

### Invariant 2 — MCP outputs ALWAYS scanned before sealing

No code path in `BASMCPCapabilityGateway.invoke(...)` accepts an output without running the tool-injection scan. The 4-step pipeline is sequential — Step 2 (scan) runs before Step 1 (seal). Verified by `testCRITICAL_OneRejectionDoesNotCorruptState` + the absence of any "skip-scan" code path in `Sources/BASMemory/BASMCPCapabilityGateway.swift`.

### Invariant 3 — Sandbox tier downgrades are NON-OPTIONAL

`BASExternalAgentGateway.effectiveTier(for:)` is the ONLY way to derive the tier. Unattested → observer + collaborator → advisor downgrades are hard-coded. Caller cannot override. Verified by `testUnattestedDowngradeToObserver` + `testCollaboratorDowngradeToAdvisor`.

### Invariant 4 — Audit prefix discipline (Phase 7 additions)

| New prefix | Format |
|---|---|
| `agentExternal.proposal:` | `agentExternal.proposal:<externalID>:<channel>:<proposalID>` |
| `agentExternal.tier:` | `agentExternal.tier:<externalID>:<effective-tier>` |
| `agentExternal.trust:` | `agentExternal.trust:<externalID>:<trust-score>` |

All Phase 7 audit refs use these prefixes. Verified by `testAuditRefsUseReservedPrefix` (ch 977).

## Rollback (if needed)

Phase 7 is fully ADR-014 OPT-IN — the MCP gateway + external gateway are NOT invoked unless caller explicitly calls them. The dispatcher in `BASAgentTurnDispatcher` is unchanged from Phase 6. If a regression is caught in either gateway:

1. Revert ch 976-978 via `git revert` on the Phase 7 commits
2. Substrate behavior fully restored — no external surfaces exposed
3. File a USER-PASS sub-chapter with the regression detail + fix

## Phase 7 summary (ch 976 + 977 + 978)

| ch | Module | LOC (Sources) | Tests |
|---|---|---|---|
| 976 | MCP Capability Gateway | ~280 | 20 |
| 977 | A2A External Gateway | ~420 | 26 |
| 978 | Phase 7 close E2E | (tests only) | 10 |
| **Total** | | **~700 LOC** | **56 tests** |

Phase 7 fully shipped:
- MCP tool/data/prompt/resource adapter through Capability Gateway (provenance seal + 4-step pipeline + injection scan)
- A2A external agent protocol-only sandboxing with 3-tier downgrade + sovereign-locked forbidden set on every degraded spec
- 4 reserved audit prefixes added for L14 absorption (`agentExternal.proposal:` / `agentExternal.tier:` / `agentExternal.trust:` + existing `agentWatcher.flag:`)
- 10 adversarial scenarios pinned

## Next phase gate

Phase 7 close is the gate to Phase 8 (End-side perf optimization + arc seal, ch 979-981):
- ch 979: Shared latent spine (one encode pass shared across agents)
- ch 980: Hot/cold agent tier (Scout + Risk-light + Sovereign-light + Surface-stub warm in-process)
- ch 981: Speculative parallelism + zero-copy state bus + **arc seal** (2-hour iPhone Air real-device smoke with all 18 agents)

Phase 8 close → arc 953-981 SEALED.
