# SDK API Stability Surface — Agent Fabric (ch 953-981)

**Arc**: Agent Fabric 953-981
**Phase**: 6 — SDK productization (ch 973-975)
**SDK version**: v1 (as of ch 974)

This document declares which Agent Fabric types are **wire-format stable** (Codable, persisted, transmitted over A2A in Phase 7), which are **library-API stable** (Swift API surface only, callable from other modules but not serialized), and which are **internal only** (subject to breaking change without notice).

---

## Stability tiers

| Tier | Stability promise | Migration cost |
|---|---|---|
| **WIRE-STABLE** | Codable schema MUST NOT change without SDK major version bump. Field additions allowed as `Optional` with default; field removals + renames are BREAKING. | breaking change → CHANGELOG entry + migration guide |
| **API-STABLE** | Swift public API MUST stay backward-compatible within an SDK major version. Method signatures may add default-valued params; removal is BREAKING. | breaking change → CHANGELOG entry |
| **INTERNAL** | May change without notice in any chapter. Test pins not required. | none |

---

## WIRE-STABLE types (Codable + persisted)

### Core schemas (ch 953)

| Type | Source file | Notes |
|---|---|---|
| `BASAgentSpec` | `Sources/BASMemory/BASAgentSpec.swift` | identity + read/write/propose/forbidden domains + lease + persona + visibility + commit |
| `BASAgentLease` | `Sources/BASMemory/BASAgentLease.swift` | per-turn budget + agent + lease ID + expires + priority |
| `BASAgentObservation` | `Sources/BASMemory/BASAgentObservation.swift` | observed-domain + source refs + summary + confidence + flags |
| `BASAgentDelta` | `Sources/BASMemory/BASAgentDelta.swift` | delta ID + target object + deltaType + patchJson + confidence + reason codes + dependencies + conflict refs |
| `BASAgentProposal` | `Sources/BASMemory/BASAgentProposal.swift` | proposal ID + type + payload + required domains + risk/sovereign notes |
| `BASAgentMergeResult` | `Sources/BASMemory/BASAgentMergeResult.swift` | accepted/rejected/conflict-resolution refs |
| `BASAgentTrace` | `Sources/BASMemory/BASAgentTrace.swift` | trace ID + lease ref + read/write refs + proposals/accepted/rejected + latency |
| `BASAgentPersonaSpec` | `Sources/BASMemory/BASAgentPersonaSpec.swift` | persona ID + 9 biases + visibility + constraint refs + version |

### Enums (ch 953-965)

| Enum | Cases | Cases pinned by test |
|---|---|---|
| `BASAgentRole` | 20 (9 core + 7 watcher + 4 sealed) | `BASChapter953AgentFabricSchemaPropertyTests.testEnumCountInvariants` |
| `BASAgentVisibility` | 3 (high / medium / low) | ↑ |
| `BASStateDomain` | 12 (after ch 965 `.evolutionProposal`) | ↑ |
| `BASAgentProposalType` | 7 | ↑ |
| `BASAgentDeltaType` | 5 | ↑ |
| `BASAgentLeaseProfile` | 4 (hot/cold/watcher/sovereign) | ↑ |

### Phase 4 persona types

| Type | Source | Stability note |
|---|---|---|
| `BASAgentPersonaRoleTemplate` | `BASAgentPersonaRoleTemplates.swift` | 12 templates pinned by test, count + tier breakdown stable |
| `BASAgentPersonaRiskContext` | `BASAgentPersonaRiskClamp.swift` | floor/ceiling fields stable |
| `BASAgentPersonaRiskClampOutcome` | ↑ | audit notes format stable (sorted) |
| `BASAgentPersonaSovereignWarrant` | `BASAgentPersonaSovereignClamp.swift` | warrant ID + grantedFields + reason |
| `BASAgentPersonaSovereignContext` | ↑ | lockdownTurn + heightenedProtection + warrant |
| `BASAgentPersonaSovereignClampOutcome` | ↑ | didClamp + audit notes + lockdownApplied |
| `BASAgentPersonaForbiddenPattern` | `BASAgentPersonaForbiddenDetector.swift` | 4 cases pinned (shame / gaslight / absolutePaternal / controlling) |
| `BASAgentPersonaForbiddenFinding` | ↑ | pattern + matchScore + sorted evidence |
| `BASAgentPersonaTranscriptMode` | `BASAgentPersonaSDK.swift` | 3 cases pinned (singleAgent / compareAll / compareSelected) |
| `BASAgentPersonaResolveRequest` | ↑ | request envelope fields stable |
| `BASAgentPersonaResolveResult` | ↑ | result envelope fields stable |

### Phase 5 watcher types

| Type | Source | Stability note |
|---|---|---|
| `BASAgentWatcherSeverity` | `BASAgentWatcher.swift` | 4 cases pinned (info / watch / alert / veto) |
| `BASAgentWatcherHint` | ↑ | hint ID + turn ID + role + severity + category + summary + sorted evidence + confidence + nowNanos |
| `BASAgentWatcherObservation` | ↑ | turn observation envelope |
| `BASWatcherAuditAggregate` | `BASAxisSanctumWatchersAggregator.swift` | turn ID + hints + bySeverity + byRole + sorted signalRefs + anyVeto + actionable |

### Phase 6 skill agent types (ch 973)

| Type | Source | Stability note |
|---|---|---|
| `BASSkillCapability` | `BASSkillAgent.swift` | 4 reference cases pinned (writing / code / research / scheduling) |
| `BASSkillAgentDescriptor` | ↑ | agent ID + capability + sorted permit/read/tool domains + persona ref + visibility + sdkVersion |
| `BASSkillAgentInvocation` | ↑ | invocation envelope |
| `BASSkillAgentInvocationResult` | ↑ | result with persona + agentSpec + outcomes + error |

---

## API-STABLE types (Swift API only)

### Resolver / clamp pure-fns

- `BASAgentPersonaResolver.resolve(...)`
- `BASAgentPersonaRiskClamp.apply(...)`
- `BASAgentPersonaSovereignClamp.apply(...)`
- `BASAgentPersonaForbiddenDetector.scan(...)` + `.anyForbidden(...)`
- `BASAgentPersonaSDK.resolve(...)` + `.validateOverlays(...)`

### Watcher dispatch

- `BASAgentWatcherDispatch.runCh970(...)` (legacy — Phase 5 pre-close)
- `BASAgentWatcherDispatch.runCh971(...)` (legacy)
- `BASAgentWatcherDispatch.runPhase5(...)` ← **canonical entry point**
- `BASAgentWatcherAggregator.runAll(...)` ← canonical aggregator
- `BASAgentWatcherAggregator.aggregate(...)` (for custom watcher sets)

### Skill agent invoker

- `BASSkillAgentInvoker.invoke(...)`
- `BASSkillAgentInvoker.buildAgentSpec(...)`
- `BASSkillAgentRegistry.referenceFor(capability:)`
- `BASSkillAgentRegistry.{writing, code, research, scheduling, all}`

### Dispatcher

- `BASAgentTurnDispatcher.dispatch(...)` ← canonical turn-level entry
- `BASAgentTurnRoster.init(...)` (constructor stable)
- `BASAgentTurnInput.init(...)` (constructor stable — new optional params added in 961/963/964/965)

### Audit-ledger signal-ref reserved prefixes

These string prefixes are reserved for the agent fabric subsystem. Other subsystems MUST NOT emit `signalRefs` starting with these prefixes:

| Prefix | Used by | Format |
|---|---|---|
| `agentFabric.activated:` | dispatcher (Phase 1+) | `agentFabric.activated:<role>:<agentID>` |
| `agentFabric.merged:` | merge engine | `agentFabric.merged:<deltaID>:<status>` |
| `agentPersona.applied:` | persona SDK | `agentPersona.applied:<personaID>:<changes>` |
| `agentPersona.clamped:` | risk + sovereign clamps | `agentPersona.clamped:<source>:<field>:<value>` |
| `agentWatcher.flag:` | watcher aggregator | `agentWatcher.flag:<role>:<category>:<hintID>` |
| `agentWatcher.count:` | watcher aggregator | `agentWatcher.count:<severity>:<count>` |

---

## INTERNAL types (subject to change)

### Pure-fn implementation helpers

- Per-seat `escapeForJSON*()` extensions in seat files (8 different variants — ch 964.5 deferred consolidation L1)
- `BASAgentPersonaResolver.ComposedPersona` (private workspace)
- `BASAgentPersonaSovereignClamp.{forceField*, lockdownForceNumeric}` helpers
- `BASAgentPersonaRiskClamp.{formatRaise, formatCap, clamp01, nanNotesFor}` helpers
- `BASAgentPersonaForbiddenDetector.{score*, isWarmTone, isColdTone, formatEv}` private scorers

### Per-seat private state

- `BASAgentTraceLog.nextSeqByTurn` ring-buffer state (ch 956.11 H2 fixed leak)
- `BASSharedStateGraph` actor's internal storage map + writer registry

---

## Versioning policy

Agent Fabric SDK follows **substrate-wide SDK versioning** (see top-level `CHANGELOG.md` for the master record):

- **SDK v1** — ch 953-975 (Phase 0 through Phase 6 close, current)
- **SDK v2** — first time we make a BREAKING wire-format change after Phase 6 close

Within v1:
- Adding a new optional Codable field with a default value is NOT breaking (older readers can parse newer payloads since they ignore unknown fields)
- Adding a new enum case is NOT breaking IFF the count pin in the corresponding test is bumped (forces a CHANGELOG entry)
- Adding a new state-graph domain is NOT breaking — but bumps `BASStateDomain.allCases.count` (pinned by test)
- Adding a new role / visibility tier / etc. follows the same rule

**BREAKING changes within v1 are forbidden** unless they're correctness fixes for sovereign-critical bugs (e.g. the ch 969.5 CG1 sovereignty crisis fix). Such fixes must:
1. Land in a USER-PASS sub-chapter
2. Include a regression test
3. Document the change in CHANGELOG + this file

---

## Breaking-change audit trail (Phase 6 review)

As of ch 974, the following types were inspected for wire-format stability:

### `BASStateDomain` count pin migration

The state domain enum has grown across chapters:
- ch 953 ships with 9 domains
- ch 961 added `.critiqueField` → 10
- ch 963 added `.alignmentField` → 11
- ch 965 added `.evolutionProposal` → 12

Each addition is BACKWARD-COMPATIBLE for readers (older readers don't know about the new domain but still parse other domains correctly). Writers using a new domain CAN'T have their writes parsed by older readers — but per the routing-only architecture, no writer of the new domain exists in older substrate versions, so this is safe.

### `BASAgentRole` (sealed at 20)

No additions since ch 953. If a future chapter adds a new role (e.g. Phase 7 external-agent role), the test count pin in `BASChapter953AgentFabricSchemaPropertyTests.testEnumCountInvariants` MUST be bumped.

### `BASAgentVisibility` (sealed at 3)

No additions. Adding a 4th tier (e.g. `.restricted`) would BREAK the resolver's switch statements (in ch 966 `applyUserOverlay` + ch 968 sovereign clamp) — that's the kind of change that needs an SDK v2.

### `BASAgentWatcherSeverity` (sealed at 4)

Pinned by ch 970 test. Adding a new severity (e.g. `.silent` for opt-in observation) would be NOT breaking IF watchers + aggregators handle unknown future severities gracefully — defer to SDK v2 if introduced.

### `BASAgentPersonaForbiddenPattern` (sealed at 4)

Pinned by ch 969. Adding a new pattern (e.g. `.coercive`) is NOT breaking — older readers ignore unknown finding patterns in the SDK result.

---

## Migration guide template (for SDK v2 when needed)

When SDK v2 is published, this section documents how consumers migrate:

```markdown
### SDK v1 → v2 migration

- [field A] removed → use [field B] instead
- [enum case X] renamed → switch statements break;update with old/new mapping
- [type Y] schema changed → re-serialize all v1 records via `BASSDKMigration.upgradeV1ToV2(...)`
```

Currently no v2 migration needed.

---

## Agent fabric SDK consumers (audit list)

| Consumer | Stability requirements |
|---|---|
| Qinao runtime (host app) | WIRE-STABLE + API-STABLE for full agent fabric surface |
| `DeviceTestApp` (ch 975 sample) | API-STABLE for `BASSkillAgentInvoker` + `BASAgentPersonaSDK` |
| Tests (`Tests/BehavioralAISubstrateTests/BASChapter95*-97*`) | Internal — pin specific behaviors per chapter |
| Future Phase 7 A2A consumers | WIRE-STABLE for all Codable types |
