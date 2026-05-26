# Phase 6 Close — iPhone Air 1-hour Real-Device Soak (Operator Procedure)

**Arc**: Agent Fabric 953-981
**Phase**: 6 — SDK productization (ch 973-975)
**Status**: simulator-verified host-level CI passes (cumulative arc 530+ tests, 0 failures) — device-verification PENDING
**Operator**: maintainer with physical iPhone Air

---

## What this smoke validates

Per plan PHASE 6 close requirements:

1. SDK-API-Stability contract holds under real-device load (all WIRE-STABLE Codable types round-trip cleanly)
2. 4 reference skill agents (writing / code / research / scheduling) all invoke cleanly through Phase 4-5 pipeline
3. `DeviceTestApp` sample host can drive a turn through `BASSkillAgentInvoker.invoke(...)` without persona rejection
4. Phase 6 cumulative perf delta ≤ +10% vs Phase 4 baseline

## Pre-flight

```bash
cd /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate
swift build
swift test --filter "BASChapter97[345]" 2>&1 | grep "Executed [0-9]"
```

Expected: clean build, all Phase 5-6 tests pass.

## DeviceTestApp sample integration

The `DeviceTestApp` Xcode project (created in ch 949 for Phase 1 iPhone Air smokes) gains a Phase 6 sample integration. The operator either uses an existing DeviceTestApp invocation harness OR wires a simple test scene that calls `BASSkillAgentInvoker.invoke(...)` for each of the 4 reference agents in sequence.

Sample integration code (operator wires in DeviceTestApp's `ContentView.swift` or equivalent):

```swift
import BASMemory

func runPhase6Demo() async -> [String] {
    var results: [String] = []
    for agent in BASSkillAgentRegistry.all {
        let invocation = BASSkillAgentInvocation(
            descriptor: agent,
            turnID: "demo-\(agent.capability.rawValue)",
            personaID: "demo-persona-\(agent.capability.rawValue)")
        let result = BASSkillAgentInvoker.invoke(invocation)
        let status = result.success
            ? "✓ \(agent.agentID)"
            : "✗ \(agent.agentID): \(result.error ?? "?")"
        results.append(status)
    }
    return results
}
```

This is intentionally minimal — the host-app's existing 14-layer smoke wrapper already exercises the substrate at higher fidelity. Phase 6 just verifies the new SDK surface compiles + runs on-device + doesn't crash.

## 1-hour soak run

```bash
MAX_SEC=3600 \
    BAS_DEVICE_LOG_DIR=/tmp/ch975-phase6-soak \
    bash scripts/run-iphone-air-10hr.sh
```

Pass criteria:

| Metric | Pass threshold | Status |
|---|---|---|
| Total failures | 0 | active |
| Phase 6 perf delta vs ch 952.6 baseline | ≤ +10% | active |
| SDK Codable round-trip drift | 0 across all WIRE-STABLE types | active (ch 974 tests confirm 0%) |
| Skill agent invocation success rate (4 reference agents, no overlay) | 100% | active (ch 973 tests confirm 100%) |
| Watcher signalRef prefix discipline | 100% reserved prefix compliance | active (ch 974 + ch 972 tests confirm 100%) |
| Persona resolver determinism | 100% byte-equal across same input | active (ch 966 + ch 969 tests confirm 100%) |

## Phase 6 deferred items (Phase 7+)

- **MCP/A2A adapters** (Phase 7 ch 976-977) — Capability Gateway wiring for tool/data/prompt/resource adapters + external agent ref handling
- **Env-var gate** (Phase 7+) — `BAS_PERSONA_ENABLED` / `BAS_WATCHERS_ENABLED` / `BAS_TRANSCRIPT_MODE` wiring in `run-iphone-air-10hr.sh` + dispatcher
- **Real consumer integration** — Phase 6 ships the SDK surface; consumer-side wiring (Qinao runtime) is a separate workstream

## Rollback (if needed)

Phase 6 is fully ADR-014 OPT-IN — skill agents are not invoked unless caller explicitly calls `BASSkillAgentInvoker.invoke(...)`. The dispatcher in `BASAgentTurnDispatcher` is unchanged from Phase 5。 If a regression is caught in any skill agent surface, revert commits for ch 973-975 via `git revert` — substrate behavior fully restored.

## Phase 6 summary (ch 973 + 974 + 975)

| ch | Module | LOC (Sources) | Tests |
|---|---|---|---|
| 973 | BASSkillAgent protocol + 4 reference agents | ~440 | 24 |
| 974 | SDK API stability docs + pin tests | ~50 | 18 |
| 975 | DeviceTestApp sample integration doc | (docs only) | — |
| **Total** | | **~490 LOC** | **42 tests** |

Plus comprehensive `Docs/SDK_API_STABILITY.md` declaring 3 stability tiers (WIRE-STABLE / API-STABLE / INTERNAL) + the SDK versioning policy + the reserved signalRefs prefix list + Phase-by-phase audit trail of enum/type count pins.

## Next phase gate

Phase 6 close is the gate to Phase 7 (MCP + A2A external, ch 976-978)。 Phase 7 wires:
- ch 976: MCP adapter into Capability Gateway (tools / data / prompt / resource adapters route through `BASActionPermit` + provenance seal) — MED risk (external surface)
- ch 977: A2A adapter as `BASExternalAgentRef` — external agents are proposal-only, tool-domain-scoped, no direct write, subject to provenance + sandbox — HIGH risk
- ch 978: End-to-end MCP+A2A test on iPhone Air with real Gemma 4 E2B internal + mock external agent — Phase 7 close
