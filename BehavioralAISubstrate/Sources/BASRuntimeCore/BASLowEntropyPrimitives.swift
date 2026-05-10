// MARK: - BASLowEntropyPrimitives — chapter 四百二十九 / M1088
// 系统熵 reduction
//
// RADICAL EVOLUTION SWEEP Phase C entry。 4 generic primitives
// that name the canonical shapes the substrate keeps
// reinventing as concrete `*Result` /
// `*FrameEnvelope` / `*Permit` / `*Card` types。
//
// (5th generic — `BASBundle<Item>` — already lives in
// `BASBundle.swift` from chapter 三百四七 / M819,with
// `BASBundleProtocol` conformance + UUID identifier。
// Phase C honors that existing primitive instead of
// duplicating it。)
//
// ## Why this exists (system entropy framing)
//
// The 2026-04-26 audit counted 1,282 public `*Frame` +
// `*Bundle` types across the substrate (79% of payload
// types)。 Inspection shows most of those follow ONE of
// 5 canonical shapes:
//
//   1. Result envelope — typed body + diagnostics +
//      success-or-failure tag
//   2. Bundle — typed item + metadata + count
//   3. Frame envelope — typed body + immutable header
//   4. Permit — typed decision + reason codes + reviewer
//      identity
//   5. Card — typed kind + body + presentation hints
//
// Each shape is reinvented per-domain (BASRAGResult,
// BASMemoryRecallResult,BASToolDispatchResult, etc.) —
// 5 generics × 100 domains = 500 named types where 5
// would suffice。
//
// `BASLowEntropyPrimitives` ships the 5 generics so
// future code converges on the canonical shapes。
// Existing concrete types are NOT replaced (would touch
// every test);typealias migration is opt-in per-domain
// and lands in follow-up chapters under explicit user
// control。
//
// ## What this ships (M1088)
//
//   - `BASResult<Body>` Sendable + Codable + Equatable
//     + Hashable struct (success / body / diagnostics)
//   - `BASFrameEnvelope<Body>` Sendable + Codable +
//     Equatable + Hashable struct (header / body)
//   - `BASPermit<Decision>` Sendable + Codable +
//     Equatable + Hashable struct (decision /
//     reasonCodes / reviewerID)
//   - `BASCard<Kind, Body>` Sendable + Codable +
//     Equatable + Hashable struct (kind / body /
//     headline / presentation)
//   - `BASFrameEnvelopeHeader` Sendable + Codable struct
//     (envelope-shared header used by `BASFrameEnvelope`)
//
// `BASBundle<Item>` from chapter 三百四七 / M819 fills
// the 5th canonical shape slot。 No duplication shipped。
//
// ## Why no typealias migration (deferred)
//
// The original Phase C plan called for shipping
// per-module typealias shims (12 Frame + 15 Bundle =
// 27 typealiases) that route existing concrete types
// onto these generics。 Two issues block that in
// autonomous mode:
//
//   1. Typealiases for generic types DO NOT route
//      extensions:if `BASRAGResult` has any extensions,
//      replacing the struct with `typealias BASRAGResult
//      = BASResult<RAGBody>` orphans those extensions。
//   2. Existing tests bind concrete types directly
//      (`let r: BASRAGResult = ...`);typealias swap
//      changes serialized field ordering which can
//      break replay-determinism golden fixtures。
//
// M1088 ships the 5 generics WITHOUT typealias swaps。
// Future chapters perform per-domain migration under
// explicit consumer-coordination。
//
// ## Doctrine pins held
//
//   - chapter 一百八十五 — anti-magic-number (typed
//     generics + named diagnostic categories)
//   - chapter 二百一一 — single source-of-truth (5
//     canonical shapes that future domain-specific
//     types reduce to)
//   - chapter 三百九二 — replay-determinism (Codable
//     via sortedKeys JSON)
//   - 不变量 #1/#2/#3 — V1 byte-equality preserved
//     (purely additive primitives;no existing concrete
//     type touched)
//   - 红线 7 — hint-only (low-entropy primitives are
//     observation/structure,no commitment authority
//     change)
//   - ADR-014 OPT-IN — purely additive

import Foundation

// MARK: - BASResult<Body>

/// Generic result envelope:typed body + ordered
/// diagnostic codes + success tag。 Replaces the 100+
/// concrete `BAS*Result` types that follow the same
/// shape (success flag + payload + diagnostics array)。
public struct BASResult<Body>:
    Equatable, Hashable, Codable, Sendable
where
    Body: Equatable & Hashable & Codable & Sendable
{

    /// Whether the operation succeeded。 If false,`body`
    /// may carry partial output;`diagnostics` should
    /// carry the failure reason codes。
    public let success: Bool

    /// Typed body payload。 Caller-defined shape per
    /// concrete instantiation。
    public let body: Body

    /// Ordered diagnostic codes in caller-defined
    /// taxonomy。 Empty when success without warnings;
    /// populated with reason codes on failure or
    /// non-blocking warnings。
    public let diagnostics: [String]

    public init(
        success: Bool,
        body: Body,
        diagnostics: [String] = []
    ) {
        self.success = success
        self.body = body
        self.diagnostics = diagnostics
    }
}

// MARK: - BASFrameEnvelope<Body>

/// Generic frame envelope:immutable header + typed body。
/// Replaces the concrete `BAS*FrameEnvelope` types that
/// pair "schema version + correlation ID + producer
/// identity" header with a payload。
public struct BASFrameEnvelope<Body>:
    Equatable, Hashable, Codable, Sendable
where
    Body: Equatable & Hashable & Codable & Sendable
{

    public let header: BASFrameEnvelopeHeader
    public let body: Body

    public init(
        header: BASFrameEnvelopeHeader,
        body: Body
    ) {
        self.header = header
        self.body = body
    }
}

/// Immutable header carried inside `BASFrameEnvelope`。
/// Captures schema version + correlation ID + producer
/// identity + emission timestamp。
public struct BASFrameEnvelopeHeader:
    Equatable, Hashable, Codable, Sendable
{

    /// Caller-defined schema version (e.g. "2.0.0")。
    public let schemaVersion: String

    /// Free-form correlation ID linking this envelope
    /// to a request / session / turn。
    public let correlationID: String

    /// Logical producer identity (e.g.
    /// "host.context-derivation",
    /// "policy.escalation-fold")。
    public let producer: String

    /// Wall-clock timestamp the envelope was sealed,
    /// in milliseconds since UNIX epoch。
    public let emittedAtMs: Int64

    public init(
        schemaVersion: String,
        correlationID: String,
        producer: String,
        emittedAtMs: Int64
    ) {
        self.schemaVersion = schemaVersion
        self.correlationID = correlationID
        self.producer = producer
        self.emittedAtMs = emittedAtMs
    }
}

// MARK: - BASPermit<Decision>

/// Generic permit:typed decision + reason codes +
/// reviewer identity。 Replaces the 50+ concrete
/// `BAS*Permit` types that name "what action is allowed,
/// why, who decided"。
public struct BASPermit<Decision>:
    Equatable, Hashable, Codable, Sendable
where
    Decision: Equatable & Hashable & Codable & Sendable
{

    /// Typed decision payload。 Caller-defined enum or
    /// struct per concrete instantiation (e.g.
    /// `BASActionPermitMode` for action permits,
    /// `BASToolPermitVerdict` for tool permits)。
    public let decision: Decision

    /// Reason codes that drove the decision。 Ordered
    /// chronologically by reviewer evaluation。
    public let reasonCodes: [String]

    /// Identity of the reviewer that issued the
    /// permit (e.g. "policy.gate-action",
    /// "sovereign.commit-permit")。
    public let reviewerID: String

    public init(
        decision: Decision,
        reasonCodes: [String],
        reviewerID: String
    ) {
        self.decision = decision
        self.reasonCodes = reasonCodes
        self.reviewerID = reviewerID
    }
}

// MARK: - BASCard<Kind, Body>

/// Generic card:typed kind + body + headline +
/// presentation hint。 Replaces the 50+ concrete
/// `BAS*Card` types (BASRiskCard,BASMergedChoice card
/// shapes,etc.) that all carry "what kind, what payload,
/// short headline, presentation hint"。
public struct BASCard<Kind, Body>:
    Equatable, Hashable, Codable, Sendable
where
    Kind: Equatable & Hashable & Codable & Sendable,
    Body: Equatable & Hashable & Codable & Sendable
{

    /// Typed kind discriminator per concrete
    /// instantiation。
    public let kind: Kind

    /// Typed body payload。
    public let body: Body

    /// Short headline (2-8 words) suitable for at-a-
    /// glance display。
    public let headline: String

    /// Presentation hint code (e.g. "rich-text",
    /// "compact", "expandable")。 Caller-defined
    /// taxonomy。
    public let presentation: String

    public init(
        kind: Kind,
        body: Body,
        headline: String,
        presentation: String
    ) {
        self.kind = kind
        self.body = body
        self.headline = headline
        self.presentation = presentation
    }
}
