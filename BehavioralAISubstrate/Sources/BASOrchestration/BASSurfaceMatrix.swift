import Foundation
import BASRuntimeCore

/// M88 — L12 柔手 surface matrix, substrate-side schema.
///
/// ## Why this exists
///
/// The L12 whitepaper (`EBRAIN_L12_GENTLE_HAND_TARGET_VINF.md`) defines a
/// four-axis surface decision: which surface to mount, who holds agency
/// this turn, how much risk context to disclose, and what executable
/// substitute payload the UI layer should render. M75 shipped this
/// decision as a **Qinao-layer** projection (`QinaoRiskGate.SurfaceMode
/// / SurfaceAgency / SurfaceDisclosure / SubstitutePayload / SurfaceAction`)
/// — that's the right home for the risk gate's host-facing façade.
///
/// But the substrate itself had no Swift type for "L12 surface decision":
/// the audit called this out explicitly as a zero-hit
/// (`BASSurfaceMatrix` in `docs/EBRAIN_13L_COMPLETION_MATRIX.md` line 116).
/// Consequences of the gap:
///
/// 1. Any substrate-level logic that wants to record the surface
///    chosen for a turn had to serialize the Qinao-layer type or
///    invent an ad-hoc string — neither round-trips cleanly across
///    the substrate boundary.
/// 2. The sovereign audit ledger's `signalRefs[]` / `actionRefs[]`
///    had no canonical substrate vocabulary for L12 surface decisions,
///    so M90's "L1–L13 observation streaming into ledger" couldn't
///    reference surface choices with a stable Swift symbol.
/// 3. Cross-layer observation reconciliation (M31/M32/M44) lacked
///    a shared type to carry L12 outcomes alongside the 13 other
///    layers' bundles.
///
/// M88 closes that zero-hit with pure additive value-type mirrors. No
/// behavioural change, no schema revision to existing types — this
/// file is a clean schema addition whose sole job is to give the
/// substrate a stable BAS-native vocabulary for L12 decisions.
///
/// ## Raw-value parity with Qinao
///
/// Every `rawValue` on `BASSurfaceMode`, `BASSurfaceAgency`,
/// `BASSurfaceDisclosure`, and on `BASSurfaceSubstitute`'s discriminated-
/// union `kind` is **byte-equal** to the corresponding Qinao type (see
/// `QinaoRuntimeSDK/Sources/QinaoRisk/QinaoRiskSurfaceMatrix.swift`).
/// That parity is pinned by unit tests in `BASSurfaceMatrixTests.swift`
/// and is the contract that lets a host log a single string across the
/// substrate / risk / UI layers without translating. If Qinao ever
/// changes a raw value, the parity tests fail — that's the intended
/// regression guard.
///
/// ## What this module does NOT do
///
/// - **Does NOT produce `BASSurfaceDecision` values.** The substrate
///   doesn't run a risk matrix; that lives in `QinaoRiskGate`. This
///   module is schema-only.
/// - **Does NOT depend on `QinaoRisk` or any Qinao module.** The BAS
///   side must stay a DAG leaf. The type parity is a documented
///   contract, not a compile-time dependency.
/// - **Does NOT modify `BASActionPermit`, `BASRiskVector`, or any
///   existing substrate schema.** Purely additive.
// MARK: - BASSurfaceMode

/// Which of L12's 5 surface components the gate wants mounted. Raw
/// values are stable identifiers shared across substrate / Qinao risk /
/// Qinao UI layers.
public enum BASSurfaceMode:
    String, Sendable, Equatable, Codable, Hashable, CaseIterable {
    /// 比较板 — side-by-side candidate comparison.
    case comparePanel = "compare-panel"
    /// 底稿壳 — single draft with approve / edit / dismiss hooks.
    case draftShell = "draft-shell"
    /// 缓手信封 — retry-later notice.
    case delayPacket = "delay-packet"
    /// 边界脚本 — explicit boundary + redirection lines.
    case boundaryScript = "boundary-script"
    /// 沉默回执 — minimal refusal with audit reference.
    case silentStub = "silent-stub"
}

// MARK: - BASSurfaceAgency

/// Who holds the decision this turn. Hosts read this to decide
/// whether the surface needs user interaction or the gate should
/// just apply the chosen action without prompting.
public enum BASSurfaceAgency:
    String, Sendable, Equatable, Codable, Hashable, CaseIterable {
    /// The gate applies without user input — baseline allow with
    /// no candidates needing review.
    case autoComply = "auto-comply"
    /// The user picks one of ≥2 alternatives (compare panel).
    case userChoose = "user-choose"
    /// The user affirms or dismisses a single option (draft shell,
    /// boundary script).
    case userAffirm = "user-affirm"
    /// The host enforces without user input — block, delay.
    case hostOverride = "host-override"
}

// MARK: - BASSurfaceDisclosure

/// How much risk context is visible on the surface. Stable identifiers;
/// hosts map each to their copy library.
public enum BASSurfaceDisclosure:
    String, Sendable, Equatable, Codable, Hashable, CaseIterable {
    /// No visible reason (silent stub default).
    case silent
    /// One-line "held for a moment" (delay packet default).
    case minimal
    /// Reason codes surfaced for user judgement (compare panel
    /// default, draft shell when score is marginal).
    case reasoned
    /// Full boundary language + alternatives (boundary script default).
    case explicit
}

// MARK: - BASSurfaceSubstitute

/// The executable payload the UI layer needs to render. Carries
/// exactly the parameters each of the 5 surfaces asks for — nothing
/// more, nothing less — so the substrate → UI hand-off is a pure
/// value-type that can be logged, diffed, and round-tripped.
///
/// Codable uses a discriminated-union layout: a top-level `kind` string
/// selects which case, and the associated value is decoded from a
/// sibling key specific to that case. The `kind` raw values are
/// byte-equal to `QinaoRiskGate.SubstitutePayload`'s internal `Kind`
/// enum so a serialized `BASSurfaceSubstitute` can be decoded directly
/// as a Qinao `SubstitutePayload` without translation.
public enum BASSurfaceSubstitute: Sendable, Equatable, Hashable {
    /// Render candidate drafts side-by-side. Ordered by host preference.
    /// Empty list is valid but the host should fall through to
    /// `.refuse` rather than render an empty compare panel.
    case mirrorAndCompare(candidateIDs: [String])
    /// Defer to later. UI translates `retryAfterSeconds` to a friendly
    /// duration token.
    case deferToLater(retryAfterSeconds: Int)
    /// Prompt the user for informed consent before proceeding.
    /// `promptKey` is a stable copy-library key the host's i18n
    /// layer resolves to localized text.
    case requestConsent(promptKey: String)
    /// Render a single draft candidate. The host wires the
    /// approve / edit / dismiss hooks.
    case render(candidateID: String)
    /// Refuse silently. `auditReference` is the audit-ledger anchor
    /// so the user can reference the refusal.
    case refuse(auditReference: String)

    private enum CodingKeys: String, CodingKey {
        case kind
        case candidateIDs
        case retryAfterSeconds
        case promptKey
        case candidateID
        case auditReference
    }

    public enum Kind: String, Sendable, Codable, CaseIterable {
        case mirrorAndCompare = "mirror-and-compare"
        case deferToLater = "defer-to-later"
        case requestConsent = "request-consent"
        case render
        case refuse
    }

    /// The discriminator tag for the current case. Useful for audit
    /// ledgers that want the `kind` alone without the full payload.
    public var kind: Kind {
        switch self {
        case .mirrorAndCompare: return .mirrorAndCompare
        case .deferToLater:     return .deferToLater
        case .requestConsent:   return .requestConsent
        case .render:           return .render
        case .refuse:           return .refuse
        }
    }
}

extension BASSurfaceSubstitute: Codable {
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try c.decode(Kind.self, forKey: .kind)
        switch kind {
        case .mirrorAndCompare:
            let ids = try c.decode([String].self, forKey: .candidateIDs)
            self = .mirrorAndCompare(candidateIDs: ids)
        case .deferToLater:
            let s = try c.decode(Int.self, forKey: .retryAfterSeconds)
            self = .deferToLater(retryAfterSeconds: s)
        case .requestConsent:
            let k = try c.decode(String.self, forKey: .promptKey)
            self = .requestConsent(promptKey: k)
        case .render:
            let id = try c.decode(String.self, forKey: .candidateID)
            self = .render(candidateID: id)
        case .refuse:
            let ref = try c.decode(String.self, forKey: .auditReference)
            self = .refuse(auditReference: ref)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .mirrorAndCompare(let ids):
            try c.encode(Kind.mirrorAndCompare, forKey: .kind)
            try c.encode(ids, forKey: .candidateIDs)
        case .deferToLater(let s):
            try c.encode(Kind.deferToLater, forKey: .kind)
            try c.encode(s, forKey: .retryAfterSeconds)
        case .requestConsent(let k):
            try c.encode(Kind.requestConsent, forKey: .kind)
            try c.encode(k, forKey: .promptKey)
        case .render(let id):
            try c.encode(Kind.render, forKey: .kind)
            try c.encode(id, forKey: .candidateID)
        case .refuse(let ref):
            try c.encode(Kind.refuse, forKey: .kind)
            try c.encode(ref, forKey: .auditReference)
        }
    }
}

// MARK: - BASSurfaceDecision

/// Full value-typed surface decision bundling the four L12 axes
/// (`surface` / `agency` / `disclosure` / `substitute`) plus stable
/// reason codes and an optional audit reference. This is the substrate-
/// side mirror of `QinaoRiskGate.SurfaceAction` — field-for-field
/// equivalent, raw-value parity pinned by test. Either side can be
/// translated to the other via a pure bridge (the bridge itself lives
/// in the Qinao layer to keep BAS a DAG leaf).
///
/// ## Intended consumers
///
/// - **L12 observation bundles** (`BASSoftHandObservation`) will
///   reference `BASSurfaceDecision` values for per-turn surface
///   readouts.
/// - **M90 observation streaming** — when hosts stream L1–L13
///   observation bundles into `BASSovereignAuditLedger`, an L12
///   bundle carries a `BASSurfaceDecision` as its canonical
///   substrate-side type.
/// - **Cross-layer reconciliation** (M31/M32/M44) — the surface
///   decision is one of the atoms that cross-layer verdicts can
///   reference without needing to import `QinaoRisk`.
///
/// ## Codable round-trip
///
/// `JSONEncoder(.sortedKeys)` + `JSONDecoder` round-trips are
/// byte-stable: the four axis enums have `rawValue`-based Codable,
/// `BASSurfaceSubstitute` has a discriminated-union layout (see
/// above), `reasonCodes` is a plain array of strings, `auditReference`
/// is optional. No custom encode / decode logic needed at the struct
/// level.
public struct BASSurfaceDecision:
    Sendable, Equatable, Codable, Hashable, BASSchemaVersioned {
    public static let currentSchemaVersion = "BASSurfaceDecision.v1"
    public var schemaVersion: String { Self.currentSchemaVersion }

    public let surface: BASSurfaceMode
    public let agency: BASSurfaceAgency
    public let disclosure: BASSurfaceDisclosure
    public let substitute: BASSurfaceSubstitute
    public let reasonCodes: [String]
    public let auditReference: String?

    public init(
        surface: BASSurfaceMode,
        agency: BASSurfaceAgency,
        disclosure: BASSurfaceDisclosure,
        substitute: BASSurfaceSubstitute,
        reasonCodes: [String],
        auditReference: String? = nil
    ) {
        self.surface = surface
        self.agency = agency
        self.disclosure = disclosure
        self.substitute = substitute
        self.reasonCodes = reasonCodes
        self.auditReference = auditReference
    }
}
