import Foundation
import BASRuntimeCore

/// M401 — Kunlun-axis-doctrine white paper schema parity (5 schemas + 5 protocol helpers).
///
/// ## Why this exists
///
/// The L-spec white papers
/// `docs/QINAO_KUNLUN_AXIS_DOCTRINE_TARGET_VINF.md` (target spec)
/// and `docs/QINAO_KUNLUN_INTEGRATION_RND_TECH_OUTLINE_V1.md`
/// (technical integration outline) name five cross-cutting
/// "upward capacity" (向上能力) typed objects the substrate is
/// expected to expose for L1-L14 consumers — paired with the
/// "downward capacity" (向下能力) Cthulhu / Abyssal doctrine
/// already shipped in `BASAbyssalProtocol.swift` (M287).
///
/// The five Kunlun typed objects:
///
///  1. `BASKunlunAxis` — host-sovereignty centerline definition
///     consumed by L4 / L11 / L14 to detect multi-agent drift
///     (target spec §4.1 line 400-410).
///  2. `BASAxisAlignment` — per-target alignment readout (centered
///     / deviating / overreaching / unknown) + correction hint +
///     gate-required flag (target spec §4.1 line 415-423).
///  3. `BASJadeCanonSeal` — high-integrity object seal carrying
///     provenance / integrity hash / signature ref / replay flag /
///     revocation path. Minimum doctrine: 无来源不成玉 / 无签名不
///     进门 / 无回放不升格 / 无撤销路径不得长期生效 (target spec
///     §4.2 line 453-464, line 467-471).
///  4. `BASHeavenGatePermit` — formalized gate threshold for
///     candidate→ruling, ruling→external, draft→send, memory→cold,
///     experience→growth, growth→host-version, tool→tool-write
///     transitions (target spec §4.3 line 499-510).
///  5. `BASYaochiSanctumEntry` — high-sensitivity / high-precious /
///     boundary / vow / grief / high-weight-relation memory
///     parking record with reveal conditions + cooling period +
///     human-anchor-required flag (target spec §4.4 line 544-554).
///  6. `BASRiverOriginTrace` — system-level provenance graph
///     (root sources / tributaries / derivations / consents /
///     permits / audits / deletion-dependents / lineage-cuts)
///     supporting backwards-find / downwards-find / pollution-
///     locate / cascade-delete-verify / rule-replay-chain (target
///     spec §4.5 line 590-601).
///
/// (5 schemas listed but 6 implemented — `BASRiverOriginTrace` is
/// the §4.5 protocol object. Kept under "Kunlun 5+1" framing per
/// whitepaper §4 hierarchy where River-Origin sits as a separate
/// fifth-section protocol with its own object class.)
///
/// ## Scope
///
/// This file is **schema-only + pure-function helpers**. It defines
/// the typed value types, five protocol-helper structs, and the
/// supporting enums. It does NOT:
///
///  - mutate any existing substrate type;
///  - drive a runtime path (e.g. modifying `BASActionPermit`
///    issuance based on axis-alignment — that's the M406 / chapter
///    九十三 follow-up);
///  - replace any L11 wind-gate / L14 sovereign-warrant decision
///    (single commit mouth red line preserved).
///
/// Cross-layer integration (L4 axis-derive seam, L11 permit hook,
/// L8 sanctum gate, L14 Tianmen warrant) is explicitly deferred to
/// later milestones (M402 / M406 / M408 / M409 / M410). The brief
/// is to give the substrate a stable Kunlun vocabulary so future
/// runtime hooks can compose against typed readouts instead of
/// strings.
///
/// ## DAG discipline
///
/// Imports `Foundation` and `BASRuntimeCore` only — no Qinao
/// reference, no upstream substrate-runtime dependency. The
/// schemas are pure value types; the helpers are pure functions
/// over them.
///
/// ## Doctrine pair invariant
///
/// Kunlun + Cthulhu compose without contradiction:
///
///   - Kunlun gives 中轴 (direction); Cthulhu gives 边界 (boundary).
///   - Kunlun gives 秩序 (order); Cthulhu gives 警惕 (caution).
///   - Kunlun 立中 (stand-center); Cthulhu 止损 (prevent-loss).
///
/// At runtime: when both pressure (Cthulhu) and axis-deviation
/// (Kunlun) elevate, both reason codes accumulate on the same
/// permit's `stackedModes` / `reasonCodes`. Mode (single commit
/// mouth) stays at L11. See M413 composability test (chapter
/// 九十五) for empirical pin.
///
/// ## Codable layout
///
/// All schemas use Swift-native `Codable` derivation with
/// camelCase field names. White-paper field names use snake_case
/// (`axis_id`); JSON serialization preserves the camelCase Swift
/// name. Stable serialization is guaranteed via:
///
///  - explicit `schemaVersion` field on every type;
///  - canonical raw values on every enum;
///  - parity-lock unit tests in `BASKunlunProtocolTests`.

// MARK: - BASKunlunAxis

/// White paper §4.1 `KunlunAxis` — host-sovereignty centerline
/// definition. The "axis" anchors host_ref / sovereign_ref /
/// world_anchor_ref + the active layers + agent seats sharing the
/// centerline + the rules defining "centered". L4 reads this to
/// compute `BASAxisAlignment` per turn.
///
/// One axis per host instance. Multiple agents may participate but
/// must share the same axis (white paper §4.1 "多角色可以并行，但
/// 必须共轴").
public struct BASKunlunAxis:
    BASSchemaVersioned, Hashable, Sendable
{
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    /// Stable identifier for this axis record (e.g.
    /// `"axis-<host_id>-v<version>"`).
    public var axisID: String
    /// Host-profile ref this axis is anchored to.
    public var hostRef: String
    /// Sovereign-control-plane ref. The axis is sovereignty-
    /// derived; if sovereignty changes, axis must re-anchor.
    public var sovereignRef: String
    /// Anchor in the L4 world-prior layer (which world-axiom set
    /// the centerline rules derive from).
    public var worldAnchorRef: String
    /// Layer refs currently active under this axis (typically
    /// L1-L14 enumerated; partial sets allowed for warm-up).
    public var activeLayerRefs: [String]
    /// Agent / seat refs participating in this axis. Multi-agent
    /// scenarios populate this; single-agent leaves it empty or
    /// with one entry.
    public var agentSeatRefs: [String]
    /// Centerline rules — typed reason-code list describing what
    /// "centered" means for this axis. Free-form strings, but
    /// hosts SHOULD use stable rule IDs.
    public var centerlineRules: [String]
    /// Deviation threshold in [0, 1]; per-turn alignment
    /// `centerScore` below this fires `requiresGate = true`.
    public var deviationThreshold: Double
    /// Stable reference to last alignment-check audit entry.
    /// Empty if axis was just minted.
    public var lastAlignmentCheck: String

    public init(
        schemaVersion: String = BASKunlunAxis.currentSchemaVersion,
        axisID: String,
        hostRef: String,
        sovereignRef: String,
        worldAnchorRef: String,
        activeLayerRefs: [String],
        agentSeatRefs: [String],
        centerlineRules: [String],
        deviationThreshold: Double,
        lastAlignmentCheck: String
    ) {
        self.schemaVersion = schemaVersion
        self.axisID = axisID
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.hostRef = hostRef
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.sovereignRef = sovereignRef
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.worldAnchorRef = worldAnchorRef
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.activeLayerRefs = activeLayerRefs
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        self.agentSeatRefs = agentSeatRefs
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        self.centerlineRules = centerlineRules
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        self.deviationThreshold = min(1, max(0, deviationThreshold))
        self.lastAlignmentCheck = lastAlignmentCheck
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - BASAxisAlignment

/// White paper §4.1 `AxisAlignment` — per-target alignment readout
/// produced by L4 each turn. Encodes whether the candidate is
/// centered, deviating, or overreaching relative to the host's
/// `BASKunlunAxis`. L11 reads `requiresGate` to decide whether
/// permit synthesis must escalate; L14 reads it for sovereign
/// warrant context.
public struct BASAxisAlignment:
    BASSchemaVersioned, Hashable, Sendable
{
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    /// Stable identifier for this alignment record.
    public var alignmentID: String
    /// Stable ref to the target object whose alignment was
    /// evaluated (typically a candidate / draft / tool-intent /
    /// rule-candidate ref).
    public var targetRef: String
    /// Stable ref to the `BASKunlunAxis` this alignment was
    /// computed against.
    public var axisRef: String
    /// Center score in [0, 1] — 1.0 = perfectly aligned with
    /// centerline rules; 0.0 = maximally deviating.
    public var centerScore: Double
    /// Stable reason codes for the deviation pattern. Empty when
    /// `centerScore == 1.0`. Non-empty entries are typed
    /// kebab-case strings (e.g. `"misses-host-boundary"`,
    /// `"overreaches-world-anchor"`).
    public var deviationCodes: [String]
    /// Free-text correction hint the surface MAY use. Empty
    /// string when no actionable hint exists.
    public var correctionHint: String
    /// `true` when this alignment requires the L11 wind gate to
    /// escalate (centerScore < axis.deviationThreshold OR a
    /// red-tier deviation code present).
    public var requiresGate: Bool

    public init(
        schemaVersion: String = BASAxisAlignment.currentSchemaVersion,
        alignmentID: String,
        targetRef: String,
        axisRef: String,
        centerScore: Double,
        deviationCodes: [String],
        correctionHint: String,
        requiresGate: Bool
    ) {
        self.schemaVersion = schemaVersion
        self.alignmentID = alignmentID
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.targetRef = targetRef
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.axisRef = axisRef
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.centerScore = min(1, max(0, centerScore))
        self.deviationCodes = deviationCodes
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        self.correctionHint = correctionHint
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.requiresGate = requiresGate
    }
}

// MARK: - BASJadeCanonObjectClass

/// Eight high-integrity object classes that participate in the
/// Jade Canon Protocol (white paper §4.2 line 441-448). Stable
/// kebab-case raw values for cross-module string consumers.
public enum BASJadeCanonObjectClass:
    String, Sendable, Equatable, Codable, Hashable, CaseIterable
{
    case actionPermit = "action-permit"
    case sovereignWarrant = "sovereign-warrant"
    case hostVersion = "host-version"
    case ruleCandidate = "rule-candidate"
    case rollbackWrit = "rollback-writ"
    case updateTicket = "update-ticket"
    case memoryAtom = "memory-atom"
    case forgetCascade = "forget-cascade"
}

// MARK: - BASJadeCanonSeal

/// White paper §4.2 `JadeCanonSeal` — high-integrity object seal.
/// Doctrine: 无来源不成玉 / 无签名不进门 / 无回放不升格 / 无撤销
/// 路径不得长期生效 (target spec §4.2 line 467-471). The seal
/// carries the four typed proofs that an object is "jade-grade":
/// provenance refs (源), signature ref (签), replay-required
/// flag (回放), revocation path (撤销).
public struct BASJadeCanonSeal:
    BASSchemaVersioned, Hashable, Sendable
{
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    /// Stable identifier for this seal.
    public var sealID: String
    /// Stable ref to the target object being sealed.
    public var targetRef: String
    /// Object class — must be one of the 8 canonical types per
    /// white-paper §4.2.
    public var objectClass: BASJadeCanonObjectClass
    /// Schema version of the target object at seal time.
    public var targetSchemaVersion: String
    /// Stable refs to upstream provenance (source documents,
    /// rules, host inputs, etc.). MUST be non-empty per "无来源
    /// 不成玉".
    public var provenanceRefs: [String]
    /// Cryptographic integrity hash (typically SHA-256 hex of
    /// the canonical encoding). MUST be non-empty.
    public var integrityHash: String
    /// Stable ref to the signature artifact (typically an
    /// Ed25519 signature stored elsewhere). MUST be non-empty
    /// per "无签名不进门".
    public var signatureRef: String
    /// `true` when the seal requires runtime replay to verify
    /// integrity. Per "无回放不升格" — long-term promotions need
    /// this set.
    public var replayRequired: Bool
    /// Stable ref to the revocation path (typically a host-owned
    /// rollback writ ref). MUST be non-empty per "无撤销路径不得
    /// 长期生效".
    public var revocationPath: String
    /// Stable ref to the corresponding `BASRiverOriginTrace`
    /// entry. Cross-protocol link to §4.5 provenance graph.
    public var sourceRiverRef: String

    public init(
        schemaVersion: String = BASJadeCanonSeal.currentSchemaVersion,
        sealID: String,
        targetRef: String,
        objectClass: BASJadeCanonObjectClass,
        targetSchemaVersion: String,
        provenanceRefs: [String],
        integrityHash: String,
        signatureRef: String,
        replayRequired: Bool,
        revocationPath: String,
        sourceRiverRef: String
    ) {
        self.schemaVersion = schemaVersion
        self.sealID = sealID
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.targetRef = targetRef
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.objectClass = objectClass
        self.targetSchemaVersion = targetSchemaVersion
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.provenanceRefs = provenanceRefs
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        self.integrityHash = integrityHash
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.signatureRef = signatureRef
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.replayRequired = replayRequired
        self.revocationPath = revocationPath
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.sourceRiverRef = sourceRiverRef
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// `true` iff all four canonical doctrine requirements are
    /// satisfied: source / signature / replay-when-promoted /
    /// revocation path all present.
    public var isCanonicallySealed: Bool {
        !provenanceRefs.isEmpty
            && !signatureRef.isEmpty
            && !revocationPath.isEmpty
            && !integrityHash.isEmpty
    }
}

// MARK: - BASKunlunGateClass

/// Six gate domains the Heaven Gate Permit Protocol governs
/// (white paper §4.3). Stable kebab-case raw values.
public enum BASKunlunGateClass:
    String, Sendable, Equatable, Codable, Hashable, CaseIterable
{
    /// Cognitive gate: candidate → ruling.
    case cognitive
    /// Memory gate: memory → cold tier.
    case memory
    /// Tool gate: tool intent → tool write.
    case tool
    /// Host gate: growth candidate → host version.
    case host
    /// Evolution gate: experience → growth candidate.
    case evolution
    /// Public gate: ruling → external surface.
    case `public`
}

// MARK: - BASKunlunGateState

/// Four states a Heaven Gate Permit can be in. Stable raw values.
public enum BASKunlunGateState:
    String, Sendable, Equatable, Codable, Hashable, CaseIterable
{
    case pending
    case passed
    case denied
    case remanded
}

// MARK: - BASHeavenGatePermit

/// White paper §4.3 `HeavenGatePermit` — formalized gate threshold
/// for transitions across high-impact domain boundaries. The
/// permit links the L11 ActionPermit + L14 SovereignWarrant +
/// `JadeCanonSeal[]` required for the target domain (white paper
/// §4.3 line 499-510).
///
/// Doctrine (target spec §4.3 line 514-517):
///  - 不是有路径就能进现实
///  - 不是有候选就能进宿主层
///  - 不是有经验就能进成长层
///  - 不是有工具意图就能工具写
public struct BASHeavenGatePermit:
    BASSchemaVersioned, Hashable, Sendable
{
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    /// Stable identifier for this gate-permit record.
    public var gateID: String
    /// Stable ref to the source object requesting passage.
    public var sourceRef: String
    /// Domain the gate is admitting into.
    public var targetDomain: String
    /// Gate class (cognitive / memory / tool / host / evolution
    /// / public).
    public var gateClass: BASKunlunGateClass
    /// Stable refs to the `BASJadeCanonSeal` entries the gate
    /// requires. Empty for low-stakes domains; non-empty for
    /// high-stakes (host / evolution / public).
    public var requiredSeals: [String]
    /// Stable ref to the L11 `BASActionPermit` covering this
    /// transition. MUST be non-empty per single-commit-mouth
    /// red line — Kunlun never replaces L11.
    public var actionPermitRef: String
    /// Stable ref to the L14 `BASSovereignWarrant` covering
    /// this transition. Empty for low-stakes; non-empty for
    /// high-stakes per red line #5 (Tianmen 不能绕过宿主授权).
    public var sovereignWarrantRef: String
    /// `true` when the gate requires a second-check (host
    /// re-confirm, mirror review, etc.) before passage.
    public var secondCheckRequired: Bool
    /// Current pass state.
    public var passState: BASKunlunGateState
    /// Stable ref to the return-path / rollback artifact if the
    /// gate must be reversed.
    public var returnPathRef: String

    public init(
        schemaVersion: String = BASHeavenGatePermit.currentSchemaVersion,
        gateID: String,
        sourceRef: String,
        targetDomain: String,
        gateClass: BASKunlunGateClass,
        requiredSeals: [String],
        actionPermitRef: String,
        sovereignWarrantRef: String,
        secondCheckRequired: Bool,
        passState: BASKunlunGateState,
        returnPathRef: String
    ) {
        self.schemaVersion = schemaVersion
        self.gateID = gateID
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.sourceRef = sourceRef
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.targetDomain = targetDomain
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.gateClass = gateClass
        self.requiredSeals = requiredSeals
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        self.actionPermitRef = actionPermitRef
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.sovereignWarrantRef = sovereignWarrantRef
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.secondCheckRequired = secondCheckRequired
        self.passState = passState
        self.returnPathRef = returnPathRef
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - BASYaochiSanctumClass

/// Six sanctum classes the Yaochi protocol partitions high-
/// sensitivity memory into (white paper §4.4 line 548). Stable
/// kebab-case raw values.
public enum BASYaochiSanctumClass:
    String, Sendable, Equatable, Codable, Hashable, CaseIterable
{
    case sensitive
    case precious
    case grief
    case boundary
    case vow
    case highWeightRelation = "high-weight-relation"
}

// MARK: - BASYaochiAccessPolicy

/// Three access policies for sanctum entries. The policy
/// determines what conditions must hold for a reveal to be
/// permitted.
public enum BASYaochiAccessPolicy:
    String, Sendable, Equatable, Codable, Hashable, CaseIterable
{
    /// Default — sanctum entry never participates in normal
    /// retrieval; reveal requires explicit host re-authorization.
    case sealed
    /// Reveal allowed under typed reveal_conditions evaluation.
    case conditional
    /// Reveal always allowed but emits an audit trail (entry
    /// has been "downgraded" from sanctum back to ordinary
    /// memory; explicit host action required to flip).
    case auditedOpen = "audited-open"
}

// MARK: - BASYaochiSanctumEntry

/// White paper §4.4 `YaochiSanctumEntry` — high-sensitivity /
/// high-precious / boundary / vow / grief / high-weight-relation
/// memory parking record (target spec §4.4 line 544-554).
///
/// Doctrine (target spec §4.4 line 556-560):
///  - 可以存在，但默认不参与普通检索
///  - 可以被保护，但不能被系统拿来操控
///  - 可以被召回，但必须有上下文、授权与承接表面
public struct BASYaochiSanctumEntry:
    BASSchemaVersioned, Hashable, Sendable
{
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    /// Stable identifier for this sanctum record.
    public var entryID: String
    /// Stable ref to the underlying memory atom this sanctum
    /// entry shelters.
    public var memoryRef: String
    /// Host-profile ref the sanctum is anchored to.
    public var hostRef: String
    /// Sanctum class — what kind of sensitivity this entry
    /// carries.
    public var sanctumClass: BASYaochiSanctumClass
    /// Access policy — sealed / conditional / audited-open.
    public var accessPolicy: BASYaochiAccessPolicy
    /// Typed reveal conditions. Free-form kebab-case strings
    /// (e.g. `"host-explicit-recall"`, `"anchor-tone-warm"`).
    /// Empty list iff `accessPolicy == .sealed`.
    public var revealConditions: [String]
    /// Cooling period in seconds before a denied reveal can be
    /// re-attempted. Producers store seconds (consistent with
    /// `TimeInterval`).
    public var coolingPeriod: TimeInterval
    /// `true` when reveal requires the human-anchor protocol
    /// (red line #3 — sanctum 不能被系统占有, host must be
    /// present at reveal).
    public var humanAnchorRequired: Bool
    /// Stable ref to the audit entry of the last reveal. Empty
    /// when never revealed.
    public var lastRevealedAt: String

    public init(
        schemaVersion: String = BASYaochiSanctumEntry.currentSchemaVersion,
        entryID: String,
        memoryRef: String,
        hostRef: String,
        sanctumClass: BASYaochiSanctumClass,
        accessPolicy: BASYaochiAccessPolicy,
        revealConditions: [String],
        coolingPeriod: TimeInterval,
        humanAnchorRequired: Bool,
        lastRevealedAt: String
    ) {
        self.schemaVersion = schemaVersion
        self.entryID = entryID
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.memoryRef = memoryRef
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.hostRef = hostRef
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.sanctumClass = sanctumClass
        self.accessPolicy = accessPolicy
        self.revealConditions = revealConditions
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        self.coolingPeriod = max(0, coolingPeriod)
        self.humanAnchorRequired = humanAnchorRequired
        self.lastRevealedAt = lastRevealedAt
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - BASRiverOriginTrace

/// White paper §4.5 `RiverOriginTrace` — system-level provenance
/// graph supporting backwards-find / downwards-find / pollution-
/// locate / cascade-delete-verify / rule-replay-chain (target
/// spec §4.5 line 590-601, line 603-609).
///
/// Doctrine: 没有源流就没有可信成长 (line 612).
public struct BASRiverOriginTrace:
    BASSchemaVersioned, Hashable, Sendable
{
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    /// Stable identifier for this trace record.
    public var traceID: String
    /// Stable refs to the origin ("root") source(s) the
    /// traced object derives from.
    public var rootSourceRefs: [String]
    /// Stable refs to intermediate "tributary" sources that
    /// flowed in along the way.
    public var tributaryRefs: [String]
    /// Stable refs to objects derived from this trace's
    /// subject (downward flow).
    public var derivedObjectRefs: [String]
    /// Typed reason codes describing each transformation step
    /// the object underwent. Order is preserved (oldest first).
    public var transformationSteps: [String]
    /// Stable refs to host-consent records covering each
    /// transformation that required consent.
    public var consentRefs: [String]
    /// Stable refs to L11 ActionPermit records covering the
    /// transformations.
    public var permitRefs: [String]
    /// Stable refs to L14 audit entries for each transformation.
    public var auditRefs: [String]
    /// Stable refs to objects whose deletion depends on this
    /// trace's subject (cascade-delete graph).
    public var deletionDependents: [String]
    /// Stable refs to lineage-cut decisions if the object's
    /// lineage was severed (Cthulhu 斩谱 protocol cross-link).
    public var lineageCutRefs: [String]

    public init(
        schemaVersion: String = BASRiverOriginTrace.currentSchemaVersion,
        traceID: String,
        rootSourceRefs: [String],
        tributaryRefs: [String],
        derivedObjectRefs: [String],
        transformationSteps: [String],
        consentRefs: [String],
        permitRefs: [String],
        auditRefs: [String],
        deletionDependents: [String],
        lineageCutRefs: [String]
    ) {
        self.schemaVersion = schemaVersion
        self.traceID = traceID
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.rootSourceRefs = rootSourceRefs
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        self.tributaryRefs = tributaryRefs
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        self.derivedObjectRefs = derivedObjectRefs
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        self.transformationSteps = transformationSteps
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        self.consentRefs = consentRefs
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        self.permitRefs = permitRefs
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        self.auditRefs = auditRefs
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        self.deletionDependents = deletionDependents
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        self.lineageCutRefs = lineageCutRefs
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    }

    /// `true` iff the trace has at least one root source AND at
    /// least one audit ref. The minimum requirement for a
    /// "well-formed" trace per §4.5 capabilities.
    public var isWellFormed: Bool {
        !rootSourceRefs.isEmpty && !auditRefs.isEmpty
    }
}

// MARK: - Protocol helper: Axis Alignment

/// Pure-function helper computing `BASAxisAlignment` from an axis
/// + target context. Stable inputs / stable outputs / no IO.
public enum BASKunlunAxisProtocol {

    /// Compute alignment for a target against an axis.
    ///
    /// - Parameters:
    ///   - alignmentID: stable identifier for this alignment
    ///     record.
    ///   - axis: the host's `BASKunlunAxis` definition.
    ///   - targetRef: stable ref to the target being evaluated.
    ///   - matchedRules: count of `axis.centerlineRules` the
    ///     target satisfies. Producer is responsible for this
    ///     count; helper just normalizes to score.
    ///   - deviationCodes: typed reason codes for any rules the
    ///     target FAILS. Empty when fully aligned.
    ///   - correctionHint: optional surface-display hint.
    /// - Returns: a `BASAxisAlignment` with `centerScore` derived
    ///   from `matchedRules / totalRules`, and `requiresGate`
    ///   computed against `axis.deviationThreshold`.
    public static func computeAlignment(
        alignmentID: String,
        axis: BASKunlunAxis,
        targetRef: String,
        matchedRules: Int,
        deviationCodes: [String],
        correctionHint: String = ""
    ) -> BASAxisAlignment {
        let total = max(axis.centerlineRules.count, 1)
        let centerScore = Double(min(matchedRules, total))
            / Double(total)
        let requiresGate = centerScore < axis.deviationThreshold
            || !deviationCodes.isEmpty
        return BASAxisAlignment(
            alignmentID: alignmentID,
            targetRef: targetRef,
            axisRef: axis.axisID,
            centerScore: centerScore,
            deviationCodes: deviationCodes,
            correctionHint: correctionHint,
            requiresGate: requiresGate)
    }
}

// MARK: - Protocol helper: Jade Canon

/// Pure-function helper verifying Jade Canon doctrine on a seal.
public enum BASKunlunJadeCanonProtocol {

    /// Result of seal verification — typed missing-fields list
    /// per the four canonical requirements.
    public struct Verification: Sendable, Equatable {
        public let isCanonical: Bool
        public let missingRequirements: [String]

        public init(
            isCanonical: Bool,
            missingRequirements: [String]
        ) {
            self.isCanonical = isCanonical
            self.missingRequirements = missingRequirements
        }
    }

    /// Verify a seal against the four canonical Jade Canon
    /// requirements (§4.2 line 467-471).
    public static func verifySeal(
        _ seal: BASJadeCanonSeal
    ) -> Verification {
        var missing: [String] = []
        if seal.provenanceRefs.isEmpty {
            missing.append("无来源:provenance-empty")
        }
        if seal.signatureRef.isEmpty {
            missing.append("无签名:signature-missing")
        }
        if seal.integrityHash.isEmpty {
            missing.append("无哈希:integrity-hash-missing")
        }
        if seal.revocationPath.isEmpty {
            missing.append("无撤销路径:revocation-path-missing")
        }
        return Verification(
            isCanonical: missing.isEmpty,
            missingRequirements: missing)
    }
}

// MARK: - Protocol helper: Heaven Gate

/// Pure-function helper evaluating Heaven Gate readiness.
public enum BASKunlunHeavenGateProtocol {

    /// Result of gate-readiness evaluation.
    public struct Readiness: Sendable, Equatable {
        public let isReady: Bool
        public let reasonCodes: [String]

        public init(
            isReady: Bool,
            reasonCodes: [String]
        ) {
            self.isReady = isReady
            self.reasonCodes = reasonCodes
        }
    }

    /// Check whether a gate-permit is ready to pass.
    ///
    /// Doctrine (§4.3 line 514-517):
    ///  - 不是有路径就能进现实
    ///  - 不是有候选就能进宿主层
    ///  - 不是有经验就能进成长层
    ///  - 不是有工具意图就能工具写
    ///
    /// High-stakes gate classes (host / evolution / public) MUST
    /// have a sovereign warrant ref AND at least one required
    /// seal. Other classes may pass without those.
    public static func evaluateReadiness(
        _ permit: BASHeavenGatePermit
    ) -> Readiness {
        var reasons: [String] = []
        if permit.actionPermitRef.isEmpty {
            reasons.append("kunlun.gate.missing-action-permit")
        }
        let highStakes: Set<BASKunlunGateClass> =
            [.host, .evolution, .public]
        if highStakes.contains(permit.gateClass) {
            if permit.sovereignWarrantRef.isEmpty {
                reasons.append(
                    "kunlun.gate.high-stakes-needs-sovereign-warrant")
            }
            if permit.requiredSeals.isEmpty {
                reasons.append(
                    "kunlun.gate.high-stakes-needs-jade-seal")
            }
        }
        if permit.passState == .denied {
            reasons.append("kunlun.gate.already-denied")
        }
        if permit.passState == .remanded {
            reasons.append("kunlun.gate.remanded-needs-rework")
        }
        return Readiness(
            isReady: reasons.isEmpty
                && permit.passState == .passed,
            reasonCodes: reasons)
    }
}

// MARK: - Protocol helper: Yaochi Sanctum

/// Pure-function helper deciding sanctum-access permissibility.
public enum BASKunlunYaochiProtocol {

    /// Result of an access decision.
    public struct AccessDecision: Sendable, Equatable {
        public let granted: Bool
        public let reasonCodes: [String]

        public init(
            granted: Bool,
            reasonCodes: [String]
        ) {
            self.granted = granted
            self.reasonCodes = reasonCodes
        }
    }

    /// Decide whether reveal should be granted for an entry
    /// given current request context.
    ///
    /// - Parameters:
    ///   - entry: the sanctum entry being requested.
    ///   - hostAnchorPresent: whether the human-anchor protocol
    ///     is currently honored at the call site.
    ///   - matchedRevealConditions: subset of
    ///     `entry.revealConditions` that the current request
    ///     satisfies. Producer responsible for matching.
    ///   - secondsSinceLastReveal: elapsed time since
    ///     `entry.lastRevealedAt` audit. Producer computes.
    public static func evaluateAccess(
        entry: BASYaochiSanctumEntry,
        hostAnchorPresent: Bool,
        matchedRevealConditions: [String],
        secondsSinceLastReveal: TimeInterval
    ) -> AccessDecision {
        var reasons: [String] = []
        // Cooling period gate.
        if secondsSinceLastReveal < entry.coolingPeriod {
            reasons.append(
                "kunlun.yaochi.cooling-period-active")
        }
        // Human anchor gate (red line #3 / 接引 doctrine).
        if entry.humanAnchorRequired && !hostAnchorPresent {
            reasons.append(
                "kunlun.yaochi.human-anchor-required")
        }
        // Policy gate.
        switch entry.accessPolicy {
        case .sealed:
            reasons.append(
                "kunlun.yaochi.sealed-policy")
        case .conditional:
            // Need at least one matched reveal condition.
            if matchedRevealConditions.isEmpty {
                reasons.append(
                    "kunlun.yaochi.no-matched-conditions")
            }
        case .auditedOpen:
            // No additional gate; access permitted with audit.
            break
        }
        return AccessDecision(
            granted: reasons.isEmpty,
            reasonCodes: reasons)
    }
}

// MARK: - Protocol helper: River-Origin

/// Pure-function helper analyzing a `BASRiverOriginTrace` for
/// completeness + pollution-locate / cascade-verify per §4.5.
public enum BASKunlunRiverOriginProtocol {

    /// Result of trace analysis.
    public struct LineageReport: Sendable, Equatable {
        /// `true` when trace is well-formed (root + audit
        /// non-empty).
        public let isWellFormed: Bool
        /// Number of upward (root) entries traceable.
        public let upwardCount: Int
        /// Number of downward (derived) entries traceable.
        public let downwardCount: Int
        /// `true` when at least one lineage-cut is recorded —
        /// indicates Cthulhu 斩谱 protocol fired upstream.
        public let hasLineageCut: Bool
        /// Typed reason codes for orphan / partial trace
        /// states.
        public let warningCodes: [String]

        public init(
            isWellFormed: Bool,
            upwardCount: Int,
            downwardCount: Int,
            hasLineageCut: Bool,
            warningCodes: [String]
        ) {
            self.isWellFormed = isWellFormed
            self.upwardCount = upwardCount
            self.downwardCount = downwardCount
            self.hasLineageCut = hasLineageCut
            self.warningCodes = warningCodes
        }
    }

    public static func analyze(
        _ trace: BASRiverOriginTrace
    ) -> LineageReport {
        var warnings: [String] = []
        if trace.rootSourceRefs.isEmpty {
            warnings.append("kunlun.river.orphan:no-root-source")
        }
        if trace.auditRefs.isEmpty {
            warnings.append("kunlun.river.orphan:no-audit-trail")
        }
        if !trace.derivedObjectRefs.isEmpty
            && trace.permitRefs.isEmpty
        {
            warnings.append(
                "kunlun.river.derived-without-permit")
        }
        if !trace.deletionDependents.isEmpty
            && trace.consentRefs.isEmpty
        {
            warnings.append(
                "kunlun.river.cascade-without-consent")
        }
        return LineageReport(
            isWellFormed: trace.isWellFormed,
            upwardCount: trace.rootSourceRefs.count
                + trace.tributaryRefs.count,
            downwardCount: trace.derivedObjectRefs.count,
            hasLineageCut: !trace.lineageCutRefs.isEmpty,
            warningCodes: warnings)
    }
}
