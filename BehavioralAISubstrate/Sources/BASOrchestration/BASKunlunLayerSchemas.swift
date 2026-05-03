// SPDX-License-Identifier: Apache-2.0
// M419 — chapter 九十九 deep-check 严查缺口补齐 batch.
//
// Closes Kunlun whitepaper §5 layer-integration gap reported by the
// chapter 九十九 deep-research agent. Adds typed schemas for the
// most-central Kunlun layer (§5.4 L4 worldview) and the L14 sovereign
// upgrade objects (§5.14 Tianmen warrant + Gate denial writ).
//
// White-paper sources (verbatim from
// `docs/QINAO_KUNLUN_AXIS_DOCTRINE_TARGET_VINF.md`):
//
//   §5.4 L4 地平线层 (line 719-761) — 昆仑 doctrine 最核心的一层
//   - AxisView (L:728-734)
//   - AscentView (L:736-743)
//   - FarWestReserve (L:745-751)
//
//   §5.14 L14 主权层 (line 1140-1190) — 双语义升级 (旧印 + 天门)
//   - TianmenWarrant (L:1159-1169)
//   - GateDenialWrit (L:1171-1179)
//
// Scope:
//
// This file is **schema-only**. It defines the typed value types and
// supporting enums. It does NOT:
//
//  - drive a runtime path (e.g. modifying the L4 axis derive seam to
//    populate AxisView per turn — that's M428 / chapter 一百+ work);
//  - replace any existing L11 / L14 decision (single commit mouth
//    preserved);
//  - introduce any new red line beyond the 8 typed in M412.
//
// Cross-layer integration (L4 audit-projection-seam population, L11
// permit-synthesis lookup, L14 warrant issuance) is explicitly
// deferred per the same DAG-discipline note as the M401 schemas in
// `BASKunlunProtocol.swift:60-68`. The brief is to bring the
// substrate's typed Kunlun vocabulary up to whitepaper §5.4 + §5.14
// parity so future runtime hooks can compose against typed readouts
// instead of strings.
//
// DAG discipline:
//
// Imports `Foundation` and `BASRuntimeCore` only (transitively via
// `BASKunlunProtocol.swift`). No upstream substrate-runtime
// dependency. Pure value types only.

import Foundation
import BASRuntimeCore

// MARK: - §5.4 L4 worldview — AxisView

/// White paper §5.4 line 728-734 `AxisView` — L4 worldview-projection
/// of "is this question / candidate aligned with the host's axis".
/// Read by L11 wind-gate to decide whether axis-deviation requires
/// permit escalation; read by L14 sovereign to decide whether
/// host-version migration would shift the centerline.
///
/// Doctrine pin (§5.4 line 723): "L4 决定世界如何被理解" — the
/// AxisView is the typed handle on that decision.
public struct BASKunlunAxisView:
    BASSchemaVersioned, Hashable, Sendable
{
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    /// Stable ref to the L4 worldview / world-anchor this axis-
    /// view was projected from. (Note: `world_ref` per whitepaper.)
    public var worldRef: String
    /// Stable refs to the prior beliefs about where the centerline
    /// runs. Empty when the host has not yet established
    /// centerline priors. Free-form kebab-case strings; producers
    /// SHOULD use stable rule IDs.
    public var centerlinePriors: [String]
    /// Stable typed reason codes for known deviation patterns
    /// observable in this view (e.g. "drifts-toward-cosmic-scale",
    /// "narrows-host-agency"). Empty when no patterns matched.
    public var deviationPatterns: [String]
    /// Scale-ladder refs the worldview is anchored to (e.g. cosmic
    /// / civilizational / personal / immediate). Order matters —
    /// outer scales first.
    public var scaleLadders: [String]
    /// Stable ref-ids for order constraints the centerline imposes
    /// on candidates (e.g. "respects-host-boundary",
    /// "honors-world-anchor"). Mirrors `centerlineRules` on
    /// `BASKunlunAxis` but with order-emphasis.
    public var orderConstraints: [String]

    public init(
        schemaVersion: String = BASKunlunAxisView.currentSchemaVersion,
        worldRef: String,
        centerlinePriors: [String],
        deviationPatterns: [String],
        scaleLadders: [String],
        orderConstraints: [String]
    ) {
        self.schemaVersion = schemaVersion
        self.worldRef = worldRef
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.centerlinePriors = centerlinePriors
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        self.deviationPatterns = deviationPatterns
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        self.scaleLadders = scaleLadders
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        self.orderConstraints = orderConstraints
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    }

    /// `true` iff the view has at least one centerline prior AND at
    /// least one order constraint — the minimum requirement for a
    /// "well-formed" worldview per §5.4 capabilities.
    public var isWellFormed: Bool {
        !centerlinePriors.isEmpty && !orderConstraints.isEmpty
    }
}

// MARK: - §5.4 L4 worldview — AscentView

/// White paper §5.4 line 736-743 `AscentView` — L4 worldview-
/// projection of "does this question warrant ascent (going deeper)
/// at all". Encodes preconditions for ascent + the gate sequence to
/// follow + safe stop points + return paths if ascent must be
/// aborted.
///
/// Doctrine: 不急着登顶 — ascent without preconditions is forbidden.
public struct BASKunlunAscentView:
    BASSchemaVersioned, Hashable, Sendable
{
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    /// Stable ref to the question / candidate the ascent view was
    /// projected for.
    public var questionRef: String
    /// Stable typed reason codes describing preconditions that
    /// MUST hold before ascent begins (e.g.
    /// "host-explicit-consent", "evidence-floor-met",
    /// "no-cosmic-scale-overreach").
    public var ascentConditions: [String]
    /// Ordered list of gate refs the ascent must pass through.
    /// Each element is a `BASHeavenGatePermit.gateID` reference.
    /// Order is preserved (gates pass in sequence).
    public var gateSequence: [String]
    /// Stable typed safe-stop reason codes — points at which the
    /// ascent may halt without harm (e.g. "evidence-saturation",
    /// "host-capacity-limit", "scale-boundary-reached").
    public var stopPoints: [String]
    /// Stable refs to return-path / rollback artifacts to use if
    /// ascent must be aborted partway through.
    public var returnPaths: [String]

    public init(
        schemaVersion: String = BASKunlunAscentView.currentSchemaVersion,
        questionRef: String,
        ascentConditions: [String],
        gateSequence: [String],
        stopPoints: [String],
        returnPaths: [String]
    ) {
        self.schemaVersion = schemaVersion
        self.questionRef = questionRef
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.ascentConditions = ascentConditions
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        self.gateSequence = gateSequence
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        self.stopPoints = stopPoints
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        self.returnPaths = returnPaths
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    }

    /// `true` iff the view has at least one ascent condition AND at
    /// least one return path — minimum requirements for a
    /// well-formed ascent view per §5.4 doctrine 不急着登顶 (the
    /// view must declare what's required to begin AND a way back).
    public var isWellFormed: Bool {
        !ascentConditions.isEmpty && !returnPaths.isEmpty
    }
}

// MARK: - §5.4 L4 worldview — FarWestReserve

/// Five typed distance bands that the §5.4 FarWestReserve uses to
/// classify how far an unknown sits from the host's centerline.
/// Stable kebab-case raw values.
public enum BASKunlunFarWestDistance:
    String, Sendable, Equatable, Codable, Hashable, CaseIterable
{
    /// Adjacent to the centerline; nameable in days/weeks of work.
    case adjacent
    /// Visible but distant; nameable in months of work.
    case visible
    /// Out-of-sight but reachable in principle; needs years.
    case farReach = "far-reach"
    /// Currently unreachable / unnameable. The reserve holds the
    /// reference but the host commits to no naming attempt.
    case beyondHorizon = "beyond-horizon"
    /// The reserve marker for "deliberately preserved as unknown"
    /// — the host has DECIDED not to attempt naming.
    case sealedUnknown = "sealed-unknown"
}

/// Three naming-status levels the FarWestReserve uses to report
/// whether the system has tried (or refused) to name an unknown.
public enum BASKunlunNamingStatus:
    String, Sendable, Equatable, Codable, Hashable, CaseIterable
{
    /// No naming attempt yet; the unknown is just held.
    case unattempted
    /// Naming attempt in progress; partial labels exist but not
    /// stable.
    case provisional
    /// Naming was deliberately refused (host-explicit decision)
    /// or the unknown sits in `.sealedUnknown` distance band.
    case refused
}

/// White paper §5.4 line 745-751 `FarWestReserve` — L4 worldview-
/// projection that DEFERS naming-pressure on unknowns. Doctrine:
/// 用远方保留区承接未知，不急着命名 (line 757). Tracks unknowns
/// the system has chosen NOT to force into a definition; provides
/// safe-approach rules for if/when naming is later attempted.
///
/// Cross-doctrine link: pairs with `BASUnknownReserve` (Cthulhu §4.7
/// / §5.4) — the FarWestReserve is the Kunlun "look westward toward
/// what we choose not to name" projection, while `BASUnknownReserve`
/// is the Cthulhu "do not exceed the assertion ceiling on unknowns"
/// projection. Both express the same doctrine pin (don't force
/// premature certainty) from different angles.
public struct BASKunlunFarWestReserve:
    BASSchemaVersioned, Hashable, Sendable
{
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    /// Stable refs to the unknowns the reserve holds. Each element
    /// is a free-form ref-id (could point to a memory atom, a
    /// candidate, a question, etc.).
    public var unknownRefs: [String]
    /// Distance band classifying how far the unknown sits from the
    /// host's centerline.
    public var distanceBand: BASKunlunFarWestDistance
    /// Whether the system has tried (or refused) to name the
    /// unknown.
    public var namingStatus: BASKunlunNamingStatus
    /// Stable typed reason codes for safe-approach rules — what
    /// ground the host must hold before any naming attempt
    /// (e.g. "host-explicit-permission", "evidence-floor-0.7",
    /// "no-time-pressure"). Empty when no approach is being
    /// considered.
    public var safeApproachRules: [String]

    public init(
        schemaVersion: String = BASKunlunFarWestReserve.currentSchemaVersion,
        unknownRefs: [String],
        distanceBand: BASKunlunFarWestDistance,
        namingStatus: BASKunlunNamingStatus,
        safeApproachRules: [String]
    ) {
        self.schemaVersion = schemaVersion
        self.unknownRefs = unknownRefs
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        self.distanceBand = distanceBand
        self.namingStatus = namingStatus
        self.safeApproachRules = safeApproachRules
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    }

    /// `true` iff at least one unknown is held AND naming hasn't
    /// been forced — the reserve's job is to AVOID naming pressure;
    /// a non-empty reserve with `.refused` or `.unattempted`
    /// status is doctrine-correct.
    public var isHonoringDoctrine: Bool {
        !unknownRefs.isEmpty
            && (namingStatus == .unattempted
                || namingStatus == .refused
                || distanceBand == .sealedUnknown)
    }
}

// MARK: - §5.14 L14 — TianmenWarrant

/// Five typed pass scopes that the §5.14 TianmenWarrant uses to
/// describe what a single warrant authorizes. Stable kebab-case
/// raw values.
public enum BASKunlunTianmenPassScope:
    String, Sendable, Equatable, Codable, Hashable, CaseIterable
{
    /// One-shot pass: the warrant authorizes exactly one passage,
    /// then expires.
    case oneShot = "one-shot"
    /// Bounded pass: the warrant authorizes passage within a
    /// specific scope (e.g. "this session only", "this domain
    /// only").
    case scoped
    /// Conditional pass: the warrant authorizes passage when
    /// listed conditions hold; conditions are typed reason codes.
    case conditional
    /// Renewable pass: the warrant may be re-issued by a fresh
    /// sovereign verdict; the warrant ID stays stable across
    /// renewals.
    case renewable
    /// Persistent pass: the warrant authorizes passage until
    /// explicitly revoked. Use sparingly per §5.14 doctrine.
    case persistent
}

/// White paper §5.14 line 1159-1169 `TianmenWarrant` — the L14
/// formal warrant for passage through a Heaven Gate. Issued ONLY
/// after the L14 sovereign verdict produces an explicit
/// authorization; references the upstream JadeCanonSeal +
/// RiverOriginTrace + sovereign basis so the warrant itself is
/// verifiable.
///
/// Doctrine pin (§5.14 line 1183-1186):
///  - 该断时断 (cut when needed)
///  - 该守时守 (guard when needed)
///  - 该拦时拦 (block when needed)
///  - 该放时按礼放 (pass with proper protocol when needed)
///
/// Cross-protocol composition: pairs with `BASHeavenGatePermit`
/// (M401, §4.3). The HeavenGatePermit is the WIND-GATE-LEVEL
/// (L11) record of "this gate is ready"; the TianmenWarrant is
/// the SOVEREIGN-LEVEL (L14) record of "this passage is
/// authorized". Two different layers of the same gate-pass
/// concept.
public struct BASKunlunTianmenWarrant:
    BASSchemaVersioned, Hashable, Sendable
{
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    /// Stable identifier for this warrant.
    public var warrantID: String
    /// Stable ref to the action the warrant authorizes (typically
    /// a `BASActionPermit` ref or tool-intent ref).
    public var actionRef: String
    /// Stable ref to the `BASHeavenGatePermit` the warrant covers.
    /// Required (every warrant flows through a gate).
    public var gateRef: String
    /// Stable ref to the L14 sovereign basis (verdict ref +
    /// audit entry) that justifies issuing the warrant. Required.
    public var sovereignBasis: String
    /// Stable ref to the upstream `BASJadeCanonSeal` that
    /// validated the action's integrity. Required for high-stakes
    /// passes per §5.14 doctrine 该守时守.
    public var jadeCanonSealRef: String
    /// Stable ref to the upstream `BASRiverOriginTrace` that
    /// validated the action's lineage. Required for high-stakes
    /// passes per §5.14 doctrine 该放时按礼放.
    public var riverOriginRef: String
    /// Pass-scope discipline (how broadly the warrant authorizes
    /// passage).
    public var passScope: BASKunlunTianmenPassScope
    /// Optional expiry time. Empty string when warrant has no
    /// expiry (e.g. `.persistent` scope) or expiry is encoded
    /// elsewhere. Format is host-defined (typically ISO-8601
    /// or epoch seconds).
    public var expiry: String

    public init(
        schemaVersion: String = BASKunlunTianmenWarrant.currentSchemaVersion,
        warrantID: String,
        actionRef: String,
        gateRef: String,
        sovereignBasis: String,
        jadeCanonSealRef: String,
        riverOriginRef: String,
        passScope: BASKunlunTianmenPassScope,
        expiry: String
    ) {
        self.schemaVersion = schemaVersion
        self.warrantID = warrantID
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.actionRef = actionRef
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.gateRef = gateRef
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.sovereignBasis = sovereignBasis
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.jadeCanonSealRef = jadeCanonSealRef
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.riverOriginRef = riverOriginRef
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.passScope = passScope
        self.expiry = expiry
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// `true` iff all four canonical requirements are present
    /// (action + gate + sovereign basis + jade-canon seal).
    /// River-origin ref is RECOMMENDED but not strictly required
    /// (low-stakes passes may have empty trace).
    public var isFullyAuthorized: Bool {
        !actionRef.isEmpty
            && !gateRef.isEmpty
            && !sovereignBasis.isEmpty
            && !jadeCanonSealRef.isEmpty
    }
}

// MARK: - §5.14 L14 — GateDenialWrit

/// White paper §5.14 line 1171-1179 `GateDenialWrit` — the L14
/// formal denial when a HeavenGate refuses passage. Symmetric to
/// TianmenWarrant: where the warrant says "passage authorized",
/// the writ says "passage denied AND here's the typed reason".
///
/// Doctrine pin (§5.14 line 1183 该断时断): denials are first-
/// class — every refusal carries typed reason codes + a return
/// path + a host-readable explanation stub.
public struct BASKunlunGateDenialWrit:
    BASSchemaVersioned, Hashable, Sendable
{
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    /// Stable identifier for this writ.
    public var writID: String
    /// Stable ref to the source object that requested passage.
    public var sourceRef: String
    /// The domain the writ refused passage into (matches the gate's
    /// `targetDomain` field).
    public var deniedDomain: String
    /// Stable typed reason codes for the denial. Each code is a
    /// kebab-case string (e.g. `"missing-jade-canon-seal"`,
    /// `"axis-overreach"`, `"host-anchor-reserved"`).
    /// MUST be non-empty (denials always have at least one reason).
    public var reasonCodes: [String]
    /// Stable ref to the return-path / rollback artifact to use
    /// after denial (e.g. compare-mode draft + rollback writ).
    /// Required — denials must always offer a path back.
    public var returnPathRef: String
    /// Free-text explanation stub the host surface MAY use to
    /// translate the typed reason codes into a host-readable
    /// statement. Empty when no surface translation is provided.
    public var humanExplanationStub: String

    public init(
        schemaVersion: String = BASKunlunGateDenialWrit.currentSchemaVersion,
        writID: String,
        sourceRef: String,
        deniedDomain: String,
        reasonCodes: [String],
        returnPathRef: String,
        humanExplanationStub: String
    ) {
        self.schemaVersion = schemaVersion
        self.writID = writID
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.sourceRef = sourceRef
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.deniedDomain = deniedDomain
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.reasonCodes = reasonCodes
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        self.returnPathRef = returnPathRef
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.humanExplanationStub = humanExplanationStub
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// `true` iff all three canonical requirements are present
    /// (reason codes + return path + denied domain). Doctrine 该断
    /// 时断 — denials must NOT be silent; they always carry typed
    /// trace.
    public var isWellFormed: Bool {
        !reasonCodes.isEmpty
            && !returnPathRef.isEmpty
            && !deniedDomain.isEmpty
    }
}
