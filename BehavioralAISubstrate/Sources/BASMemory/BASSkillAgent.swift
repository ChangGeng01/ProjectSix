// MARK: - BASSkillAgent
// chapter 九百七十三 / M3570 — Phase 6 ch1:SDK productization
//
// User design Section 5.3 + plan PHASE 6:Skill agents are
// SDK-PRODUCT-ATTACHED agents — N per SDK consumer (writing /
// code / research / scheduling / etc.)。 Each is scoped to a
// CAPABILITY DOMAIN + PERMIT DOMAIN + MEMORY DOMAIN + TOOL
// DOMAIN quad,unlike core agents which serve the full host。
//
// Per plan Phase 6 ch1:MED risk (first public SDK surface
// beyond persona)。 Skill agents ride on top of the Phase 1-5
// fabric — they DO NOT bypass any of the Phase 1-5 invariants
// (Single-Writer-Per-Domain,Risk + Sovereign clamps,Watcher
// safety filters)。 What they ADD is a per-consumer capability
// scope so external SDK consumers can attach domain-specific
// agents without bloating the core 9-seat roster。
//
// ## What a skill agent IS NOT
//
// - NOT a replacement for the core 9 agents (Scout / Planner /
//   Memory / Critic / HostAlign / Risk / Surface /
//   SovereignSentinel / EvolutionShadow)
// - NOT a new state-graph domain owner (each skill agent
//   shares the existing 12 domains from ch 953-965)
// - NOT a way to bypass watchers or persona clamps
//
// ## What a skill agent IS
//
// A SLIM DESCRIPTOR + INVOCATION ENVELOPE。 The descriptor says:
//   - what capability domain it covers (e.g. .writing)
//   - what permit domains it's allowed to write through (e.g.
//     .draftCompose) — checked by L11 ActionPermit
//   - what memory domains it can read from (e.g. .memoryBundle,
//     .candidateFrontier) — checked by ch 953 readDomains
//   - what tool domains its tools may invoke (e.g. MCP server
//     IDs the Capability Gateway will let through in Phase 7)
//
// The invocation envelope says:
//   - which skill agent (by agentID)
//   - turn-level inputs (subset of dispatcher's input)
//   - persona overlay (optional,goes through Phase 4 SDK)
//   - sovereign warrant (optional,goes through Phase 4 SDK)
//
// ## Pure-fn + slim DTO discipline
//
// Per ch 957-972 — pure functions,no actor,no I/O。 Caller
// (Qinao runtime,3rd-party host) constructs the invocation
// envelope + calls `BASSkillAgentInvoker.invoke(...)`。 The
// invoker:
//   1. Validates the skill agent against the descriptor
//      (capability + permit + memory + tool domain checks)
//   2. Resolves persona via Phase 4 SDK
//   3. Returns the resolved agent ready for the dispatcher
//
// Phase 6 ch1 ships the descriptor + invoker + 4 reference
// skill agents。 Phase 7 ch 976 will wire the Capability
// Gateway for tool/MCP/A2A invocations through these
// descriptors。

import Foundation

// MARK: - Skill capability

/// User design Section 5.3 + plan PHASE 6:4 reference
/// capabilities shipped。 SDK consumer may declare new
/// capabilities by extending this enum in their own module
/// (or per plan ch 974 — by passing a raw String through
/// `BASSkillCapability.custom`)。 The 4 reference cases are
/// PINNED for the SDK so external consumers can rely on them
/// existing across versions。
public enum BASSkillCapability: String,
    Sendable, Equatable, Hashable, Codable, CaseIterable
{
    /// Drafting,composing,editing prose / messages /
    /// documents。 Memory: candidateFrontier + memoryBundle。
    /// Permits: draft-compose,draft-replace。
    case writing

    /// Code generation,editing,review,debugging。 Memory:
    /// candidateFrontier + memoryBundle + critiqueField。
    /// Permits: code-write,code-test,code-review。
    case code

    /// Research,information gathering,citation。 Memory:
    /// candidateFrontier + memoryBundle + situationField。
    /// Permits: tool-search,tool-fetch (read-only)。
    case research

    /// Calendar,task management,reminders。 Memory:
    /// candidateFrontier + memoryBundle + renderFrame。
    /// Permits: schedule-write,schedule-delete (heightened
    /// risk — delete needs sovereign warrant)。
    case scheduling
}

// MARK: - Skill agent descriptor

/// Slim descriptor for a skill agent。 Caller (SDK consumer)
/// supplies this once at registration time;invocation envelope
/// references it by `agentID`。 All fields are Codable +
/// Sendable + Hashable so the descriptor can be persisted +
/// transmitted over A2A in Phase 7。
public struct BASSkillAgentDescriptor:
    Sendable, Equatable, Hashable, Codable
{
    /// Stable unique agent ID。 Format suggestion:
    /// `skill.<capability>.<consumerID>.<v>` —
    /// e.g. `skill.writing.qinao-runtime.v3`。
    public let agentID: String

    /// What this agent does。 Drives the default
    /// capability+permit+memory mapping for the Phase 4
    /// persona resolver。
    public let capability: BASSkillCapability

    /// Permit-domain identifiers the skill agent may write
    /// through (L11 ActionPermit checks these)。 Sorted by
    /// caller (or by `init` — see below)。
    public let allowedPermitDomains: [String]

    /// State-graph domains the skill agent may READ from
    /// (not write)。 Skill agents never own a domain — they
    /// always read the existing 12 domains from ch 953-965。
    /// Per Single-Writer-Per-Domain invariant。
    public let allowedReadDomains: [BASStateDomain]

    /// Tool-domain IDs the skill agent's tools may invoke
    /// through the Capability Gateway (Phase 7 ch 976)。
    /// e.g. ["mcp.filesystem","mcp.calendar"]。 Sorted。
    public let allowedToolDomains: [String]

    /// Reference to a persona overlay,nil = use role template
    /// default。 The persona MUST go through Phase 4 SDK
    /// (`BASAgentPersonaSDK.resolve`) at invocation time。
    public let personaRef: String?

    /// Visibility tier for the skill agent — `.high` allows
    /// full persona customization;`.medium` limits to style;
    /// `.low` is sealed-default (rare for skill agents,but
    /// supported per ch 968)。
    public let visibility: BASAgentVisibility

    /// SDK version this descriptor was registered under。
    /// Caller bumps this when adding/removing allowed domains
    /// so consumers can detect breaking changes (per Phase 6
    /// ch 974 wire-format-stability discipline)。
    public let sdkVersion: String

    public init(
        agentID: String,
        capability: BASSkillCapability,
        allowedPermitDomains: [String] = [],
        allowedReadDomains: [BASStateDomain] = [],
        allowedToolDomains: [String] = [],
        personaRef: String? = nil,
        visibility: BASAgentVisibility = .high,
        sdkVersion: String = "v1"
    ) {
        self.agentID = agentID
        self.capability = capability
        // Sort domains in init for deterministic round-trip +
        // stable Hashable
        self.allowedPermitDomains =
            allowedPermitDomains.sorted()
        self.allowedReadDomains = allowedReadDomains.sorted {
            $0.rawValue < $1.rawValue
        }
        self.allowedToolDomains =
            allowedToolDomains.sorted()
        self.personaRef = personaRef
        self.visibility = visibility
        self.sdkVersion = sdkVersion
    }
}

// MARK: - Reference skill agents registry

/// 4 reference skill agents per plan PHASE 6 ch1。 SDK
/// consumers can use these directly or use them as templates
/// for their own。 Each is PINNED for the SDK — count
/// asserted by ch 973 tests。
public enum BASSkillAgentRegistry {

    /// Pinned count for ch 973 test assertions。
    public static let expectedAgentCount: Int = 4

    public static let writing: BASSkillAgentDescriptor =
        BASSkillAgentDescriptor(
            agentID: "skill.writing.reference.v1",
            capability: .writing,
            allowedPermitDomains: [
                "draft-compose", "draft-replace",
            ],
            allowedReadDomains: [
                .candidateFrontier,
                .memoryBundle,
                .renderFrame,
            ],
            allowedToolDomains: [],
            personaRef: nil,
            visibility: .high,
            sdkVersion: "v1")

    public static let code: BASSkillAgentDescriptor =
        BASSkillAgentDescriptor(
            agentID: "skill.code.reference.v1",
            capability: .code,
            allowedPermitDomains: [
                "code-write", "code-test", "code-review",
            ],
            allowedReadDomains: [
                .candidateFrontier,
                .memoryBundle,
                .critiqueField,
            ],
            allowedToolDomains: [],
            personaRef: nil,
            visibility: .high,
            sdkVersion: "v1")

    public static let research: BASSkillAgentDescriptor =
        BASSkillAgentDescriptor(
            agentID: "skill.research.reference.v1",
            capability: .research,
            allowedPermitDomains: [
                "tool-search", "tool-fetch",
            ],
            allowedReadDomains: [
                .candidateFrontier,
                .memoryBundle,
                .situationField,
            ],
            allowedToolDomains: [],
            personaRef: nil,
            visibility: .high,
            sdkVersion: "v1")

    public static let scheduling: BASSkillAgentDescriptor =
        BASSkillAgentDescriptor(
            agentID: "skill.scheduling.reference.v1",
            capability: .scheduling,
            allowedPermitDomains: [
                "schedule-write", "schedule-delete",
            ],
            allowedReadDomains: [
                .candidateFrontier,
                .memoryBundle,
                .renderFrame,
            ],
            allowedToolDomains: [],
            personaRef: nil,
            // MED visibility for scheduling — delete is risky
            // enough that we don't want full persona overlay
            visibility: .medium,
            sdkVersion: "v1")

    /// All 4 reference agents,sorted by capability rawValue
    /// for deterministic iteration。
    public static let all:
        [BASSkillAgentDescriptor] = [
            code, research, scheduling, writing,
        ]

    /// Lookup by capability。 Returns the reference agent for
    /// that capability,or nil if not in the reference set。
    public static func referenceFor(
        capability: BASSkillCapability
    ) -> BASSkillAgentDescriptor? {
        switch capability {
        case .writing: return writing
        case .code: return code
        case .research: return research
        case .scheduling: return scheduling
        }
    }
}

// MARK: - Skill agent invocation envelope

/// Per-turn invocation request。 SDK consumer constructs this
/// before invoking `BASSkillAgentInvoker.invoke(...)`。 Slim
/// envelope — turn input + persona + sovereign context。
public struct BASSkillAgentInvocation:
    Sendable, Equatable
{
    public let descriptor: BASSkillAgentDescriptor
    public let turnID: String
    public let userOverlay: BASAgentPersonaSpec?
    public let hostOverlay: BASAgentPersonaSpec?
    public let risk: BASAgentPersonaRiskContext
    public let sovereign: BASAgentPersonaSovereignContext
    /// Caller-supplied persona ID for the resolved persona
    /// (per Phase 4 SDK contract)
    public let personaID: String

    public init(
        descriptor: BASSkillAgentDescriptor,
        turnID: String,
        userOverlay: BASAgentPersonaSpec? = nil,
        hostOverlay: BASAgentPersonaSpec? = nil,
        risk: BASAgentPersonaRiskContext = .identity,
        sovereign: BASAgentPersonaSovereignContext =
            .identity,
        personaID: String
    ) {
        self.descriptor = descriptor
        self.turnID = turnID
        self.userOverlay = userOverlay
        self.hostOverlay = hostOverlay
        self.risk = risk
        self.sovereign = sovereign
        self.personaID = personaID
    }
}

// MARK: - Skill agent invocation result

public struct BASSkillAgentInvocationResult:
    Sendable, Equatable
{
    /// True if invocation completed cleanly — persona resolved,
    /// no forbidden patterns,no domain violations。 When false,
    /// `error` carries the reason。
    public let success: Bool
    /// Resolved + clamped persona (per Phase 4 SDK)。 Nil when
    /// success=false (persona resolution rejected or skipped)。
    public let persona: BASAgentPersonaSpec?
    /// The `BASAgentSpec` produced from the descriptor — ready
    /// to register with `BASAgentRegistry` (ch 956)。 Nil on
    /// failure。
    public let agentSpec: BASAgentSpec?
    /// Persona resolver result (carries findings / clamp
    /// outcomes for audit ledger)。
    public let personaResult: BASAgentPersonaResolveResult?
    /// Reason code if `success == false`。 e.g.
    /// "invocation.persona-rejected" /
    /// "invocation.invalid-descriptor" /
    /// "invocation.domain-violation"。
    public let error: String?

    public init(
        success: Bool,
        persona: BASAgentPersonaSpec? = nil,
        agentSpec: BASAgentSpec? = nil,
        personaResult:
            BASAgentPersonaResolveResult? = nil,
        error: String? = nil
    ) {
        self.success = success
        self.persona = persona
        self.agentSpec = agentSpec
        self.personaResult = personaResult
        self.error = error
    }
}

// MARK: - Invoker

public enum BASSkillAgentInvoker {

    /// Full skill-agent invocation pipeline。 Pure function。
    /// Same shape as `BASAgentPersonaSDK.resolve(...)` —
    /// declarative envelope in,result with persona + agent
    /// spec out。 Caller plumbs the result into the dispatcher
    /// when ready。
    ///
    /// Pipeline:
    ///   1. Validate descriptor (empty agentID,unsupported
    ///      capability,etc。 → fast reject)
    ///   2. Build the BASAgentSpec from descriptor
    ///      (writeDomains: [] since skill agents are not
    ///      writers,proposeDomains: from allowedPermitDomains
    ///      mapping)
    ///   3. Resolve persona via Phase 4 SDK
    ///   4. Return result with agentSpec + persona + outcomes
    public static func invoke(
        _ invocation: BASSkillAgentInvocation
    ) -> BASSkillAgentInvocationResult {
        // Step 1:validate descriptor
        if invocation.descriptor.agentID.isEmpty {
            return BASSkillAgentInvocationResult(
                success: false,
                error: "invocation.invalid-descriptor:" +
                    "empty-agent-id")
        }
        if invocation.turnID.isEmpty {
            return BASSkillAgentInvocationResult(
                success: false,
                error: "invocation.invalid-envelope:" +
                    "empty-turn-id")
        }

        // Step 2:build BASAgentSpec from descriptor
        let agentSpec = buildAgentSpec(
            from: invocation.descriptor)

        // Step 3:resolve persona via Phase 4 SDK
        let personaResult =
            BASAgentPersonaSDK.resolve(
                BASAgentPersonaResolveRequest(
                    agentSpec: agentSpec,
                    userOverlay: invocation.userOverlay,
                    hostOverlay: invocation.hostOverlay,
                    risk: invocation.risk,
                    sovereign: invocation.sovereign,
                    personaID: invocation.personaID))

        // Step 4:if persona rejected,fail clean
        if personaResult.rejected {
            return BASSkillAgentInvocationResult(
                success: false,
                personaResult: personaResult,
                error: "invocation.persona-rejected")
        }

        return BASSkillAgentInvocationResult(
            success: true,
            persona: personaResult.persona,
            agentSpec: agentSpec,
            personaResult: personaResult,
            error: nil)
    }

    /// Convert a descriptor into a `BASAgentSpec` — bridges
    /// the SDK surface (Phase 6) to the core agent registry
    /// (ch 956)。 Skill agents:
    ///   - role:`.compareModerator` (DESIGN CHOICE — see below)
    ///   - writeDomains:[] (skill agents never own a state
    ///     graph domain per Single-Writer-Per-Domain)
    ///   - readDomains:from descriptor
    ///   - proposeDomains:[] (proposals go through core
    ///     agents — skill agents emit invocations,not proposals
    ///     directly to the state graph)
    ///   - leaseProfile:`.coldSeat` (skill agents cold-start on
    ///     demand)
    ///
    /// chapter 九百八十一.5 USER-PASS-7 H2 doc-fix:explicit
    /// design note on the `.compareModerator` role choice。
    /// This is INTENTIONAL,not a placeholder:
    ///
    /// 1. **Role discipline**:Phase 1-5 reserves 9 core roles
    ///    (scout/planner/memory/critic/hostAlign/risk/surface/
    ///    sovereignSentinel/evolutionShadow) for the substrate's
    ///    own seats。 Skill agents are SDK-product-attached —
    ///    they're peripheral by design,not core seats。
    ///
    /// 2. **Tier discipline** (ch 980):`.compareModerator` maps
    ///    to `.sealed` tier in `BASAgentTierRegistry`,which
    ///    means skill agents pre-initialize once per session +
    ///    have ~0ms wake cost。 This is correct for SDK
    ///    consumers:they want the skill agent ready when their
    ///    capability is requested,not eating cold-start budget
    ///    on every turn。
    ///
    /// 3. **Permit-domain discipline**:`allowedPermitDomains`
    ///    on the descriptor (e.g. ["draft-compose", "code-write"])
    ///    are STRING permit IDs,NOT `BASStateDomain` cases。
    ///    They're consumed at runtime by L11 ActionPermit when
    ///    a tool is invoked,NOT by the dispatcher's domain-
    ///    write check (which uses `BASAgentSpec.writeDomains` /
    ///    `proposeDomains`)。 So mapping them into
    ///    `proposeDomains` would be a category error。 The
    ///    silent drop is INTENTIONAL — the descriptor's
    ///    permit-domains list survives in the audit ledger via
    ///    invocation envelopes,not via the agent spec。
    ///
    /// 4. **`forbiddenDomains`** hard-coded list defends against
    ///    descriptor-construction mistakes by the SDK consumer。
    ///    Includes the 4 sovereign-locked domains
    ///    (`hostVersion` / `sovereignVerdict` / `actionPermit` /
    ///    `evolutionProposal`)。 Phase 7 ch 977 external
    ///    gateway uses a STRICTER list (all 12 domains) since
    ///    external is HIGH risk;skill agents are MED risk
    ///    (internal SDK consumer) so only sovereign-adjacent
    ///    domains are hard-forbidden。
    public static func buildAgentSpec(
        from descriptor: BASSkillAgentDescriptor
    ) -> BASAgentSpec {
        BASAgentSpec(
            agentID: descriptor.agentID,
            role: .compareModerator,
            readDomains: descriptor.allowedReadDomains,
            writeDomains: [],
            proposeDomains: [],
            forbiddenDomains: forbiddenForSkill(),
            defaultLeaseProfile: .coldSeat,
            personaRef: descriptor.personaRef,
            visibility: descriptor.visibility,
            commitCapability: false)
    }

    /// Skill agents are PROHIBITED from writing sovereign-
    /// adjacent or sovereign-locked domains — per Root Law 4
    /// (单主权)。 Hard-coded forbidden set defends against
    /// caller mistakes when constructing the descriptor。
    private static func forbiddenForSkill() -> [BASStateDomain] {
        [
            .hostVersion,
            .sovereignVerdict,
            .actionPermit,
            .evolutionProposal,
        ]
    }
}
