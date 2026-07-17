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

// MARK: - Canonical turn-operation identity

/// An ordinary Artifact Mesh reference to the immutable admission-time turn
/// operation payload. The Artifact Mesh ID is the only root identity; legacy
/// strings are bounded compatibility projections of this value.
public struct BASTurnOperationRef: Codable, Sendable, Hashable {
    public let artifactID: BASArtifactID

    public init(artifactID: BASArtifactID) throws {
        do {
            _ = try artifactID.storageScalar
        } catch {
            throw BASTurnOperationRefError.invalidArtifactID
        }
        self.artifactID = artifactID
    }

    public func canonicalLegacyProjection() throws -> String {
        let bytes = BASSovereignCanonicalBytes.lengthPrefixed([
            "bas-turn-operation-ref-v1",
            try artifactID.storageScalar,
        ])
        return bytes.base64EncodedString()
    }

    public init(
        validatingCanonicalLegacyProjection projection: String
    ) throws {
        let fields: [String]
        do {
            fields = try BASTurnLegacyProjectionDecoder.decode(projection)
        } catch BASTurnLegacyProjectionDecodeError.nonCanonicalProjection {
            throw BASTurnOperationRefError.nonCanonicalProjection
        } catch {
            throw BASTurnOperationRefError.malformedProjection
        }
        guard fields.count == 2 else {
            throw BASTurnOperationRefError.malformedProjection
        }
        guard fields[0] == "bas-turn-operation-ref-v1" else {
            throw BASTurnOperationRefError.unsupportedVersion
        }
        do {
            try self.init(artifactID: BASArtifactID(storageScalar: fields[1]))
        } catch let error as BASTurnOperationRefError {
            throw error
        } catch {
            throw BASTurnOperationRefError.invalidArtifactID
        }
        guard try canonicalLegacyProjection() == projection else {
            throw BASTurnOperationRefError.nonCanonicalProjection
        }
    }

    private enum CodingKeys: String, CodingKey {
        case artifactID
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            artifactID: container.decode(
                BASArtifactID.self,
                forKey: .artifactID))
    }
}

public enum BASTurnOperationRefError: Error, Sendable, Equatable {
    case invalidArtifactID
    case malformedProjection
    case unsupportedVersion
    case nonCanonicalProjection
}

/// The only externally meaningful branch dimensions below one turn root.
public enum BASTurnBranchKind: String, Codable, Sendable, Hashable, CaseIterable {
    case providerEgress
    case provisionalStream
    case finalPublication
    case effect
}

/// A typed branch below one canonical turn-operation root.
public struct BASTurnBranchRef: Codable, Sendable, Hashable {
    public let turnOperationRef: BASTurnOperationRef
    public let kind: BASTurnBranchKind
    public let ordinal: UInt64

    public init(
        turnOperationRef: BASTurnOperationRef,
        kind: BASTurnBranchKind,
        ordinal: UInt64
    ) throws {
        if kind == .provisionalStream || kind == .finalPublication,
           ordinal != 0
        {
            throw BASTurnBranchRefError.nonzeroSingletonOrdinal(kind: kind)
        }
        self.turnOperationRef = turnOperationRef
        self.kind = kind
        self.ordinal = ordinal
    }

    public func canonicalLegacyProjection() throws -> String {
        let bytes = BASSovereignCanonicalBytes.lengthPrefixed([
            "bas-turn-branch-ref-v1",
            try turnOperationRef.artifactID.storageScalar,
            kind.rawValue,
            String(ordinal),
        ])
        return bytes.base64EncodedString()
    }

    public init(
        validatingCanonicalLegacyProjection projection: String
    ) throws {
        try self.init(
            validatingCanonicalLegacyProjection: projection,
            expectedTurnOperationRef: nil)
    }

    public init(
        validatingCanonicalLegacyProjection projection: String,
        expectedTurnOperationRef: BASTurnOperationRef
    ) throws {
        try self.init(
            validatingCanonicalLegacyProjection: projection,
            expectedTurnOperationRef: Optional(expectedTurnOperationRef))
    }

    private init(
        validatingCanonicalLegacyProjection projection: String,
        expectedTurnOperationRef: BASTurnOperationRef?
    ) throws {
        let fields: [String]
        do {
            fields = try BASTurnLegacyProjectionDecoder.decode(projection)
        } catch BASTurnLegacyProjectionDecodeError.nonCanonicalProjection {
            throw BASTurnBranchRefError.nonCanonicalProjection
        } catch {
            throw BASTurnBranchRefError.malformedProjection
        }
        guard fields.count == 4 else {
            throw BASTurnBranchRefError.malformedProjection
        }
        guard fields[0] == "bas-turn-branch-ref-v1" else {
            throw BASTurnBranchRefError.unsupportedVersion
        }
        let operation: BASTurnOperationRef
        do {
            operation = try BASTurnOperationRef(
                artifactID: BASArtifactID(storageScalar: fields[1]))
        } catch {
            throw BASTurnBranchRefError.invalidParent
        }
        guard expectedTurnOperationRef == nil
                || expectedTurnOperationRef == operation
        else {
            throw BASTurnBranchRefError.parentMismatch
        }
        guard let decodedKind = BASTurnBranchKind(rawValue: fields[2]) else {
            throw BASTurnBranchRefError.unsupportedKind
        }
        guard !fields[3].isEmpty,
              !(fields[3].count > 1 && fields[3].first == "0"),
              let decodedOrdinal = UInt64(fields[3]),
              fields[3] == String(decodedOrdinal)
        else {
            throw BASTurnBranchRefError.invalidOrdinal
        }
        try self.init(
            turnOperationRef: operation,
            kind: decodedKind,
            ordinal: decodedOrdinal)
        guard try canonicalLegacyProjection() == projection else {
            throw BASTurnBranchRefError.nonCanonicalProjection
        }
    }

    private enum CodingKeys: String, CodingKey {
        case turnOperationRef
        case kind
        case ordinal
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            turnOperationRef: container.decode(
                BASTurnOperationRef.self,
                forKey: .turnOperationRef),
            kind: container.decode(
                BASTurnBranchKind.self,
                forKey: .kind),
            ordinal: container.decode(UInt64.self, forKey: .ordinal))
    }
}

public enum BASTurnBranchRefError: Error, Sendable, Equatable {
    case malformedProjection
    case unsupportedVersion
    case invalidParent
    case parentMismatch
    case unsupportedKind
    case invalidOrdinal
    case nonzeroSingletonOrdinal(kind: BASTurnBranchKind)
    case nonCanonicalProjection
}

// MARK: - Provider execution vocabulary

/// The policy-owned semantic purpose of one Provider branch.
public enum BASProviderStepPurpose:
    String, Codable, Sendable, Hashable, CaseIterable
{
    case groundingProposal
    case turnStep
    case verifierProposal
}

/// Whether a Provider branch is an internal proposal or the one answer
/// candidate eligible for terminal-source designation.
public enum BASProviderOutputRole:
    String, Codable, Sendable, Hashable, CaseIterable
{
    case internalProposal
    case terminalAnswerCandidate
}

/// The policy-frozen mode controlling when verified Provider bytes may become
/// visible.
public enum BASProviderVisibilityMode:
    String, Codable, Sendable, Hashable, CaseIterable
{
    case incrementalVerified
    case bufferedUntilVerified
}

private struct BASProviderExecutionRefWireCodingKey: CodingKey {
    let stringValue: String
    let intValue: Int?

    init?(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }

    init?(intValue: Int) {
        self.stringValue = String(intValue)
        self.intValue = intValue
    }
}

/// The complete branch-bound identity echoed by one Provider execution.
/// Sequence zero is the allocation/claim base. Trusted local construction of
/// a nonzero event uses only `withRequestSequence(_:)`. Codable accepts a
/// structurally valid nonzero wire value without granting it authority; the
/// outer owner must still match the K3 base, next sequence, and event digest.
public struct BASProviderExecutionRef: Codable, Sendable, Hashable {
    public let turnOperationRef: BASTurnOperationRef
    public let providerEgressBranchRef: BASTurnBranchRef
    public let attemptRef: BASArtifactID
    public let leaseID: BASArtifactID
    public let providerExecutionID: String
    public let acceptanceGeneration: UInt64
    public let requestSequence: UInt64

    /// Creates the canonical allocation/claim identity. Public callers cannot
    /// mint an event sequence directly.
    public init(
        turnOperationRef: BASTurnOperationRef,
        providerEgressBranchRef: BASTurnBranchRef,
        attemptRef: BASArtifactID,
        leaseID: BASArtifactID,
        providerExecutionID: String,
        acceptanceGeneration: UInt64
    ) throws {
        try Self.validate(
            turnOperationRef: turnOperationRef,
            providerEgressBranchRef: providerEgressBranchRef,
            attemptRef: attemptRef,
            leaseID: leaseID,
            providerExecutionID: providerExecutionID)
        self.turnOperationRef = turnOperationRef
        self.providerEgressBranchRef = providerEgressBranchRef
        self.attemptRef = attemptRef
        self.leaseID = leaseID
        self.providerExecutionID = providerExecutionID
        self.acceptanceGeneration = acceptanceGeneration
        self.requestSequence = 0
    }

    private init(
        validating turnOperationRef: BASTurnOperationRef,
        providerEgressBranchRef: BASTurnBranchRef,
        attemptRef: BASArtifactID,
        leaseID: BASArtifactID,
        providerExecutionID: String,
        acceptanceGeneration: UInt64,
        requestSequence: UInt64
    ) throws {
        try Self.validate(
            turnOperationRef: turnOperationRef,
            providerEgressBranchRef: providerEgressBranchRef,
            attemptRef: attemptRef,
            leaseID: leaseID,
            providerExecutionID: providerExecutionID)
        self.turnOperationRef = turnOperationRef
        self.providerEgressBranchRef = providerEgressBranchRef
        self.attemptRef = attemptRef
        self.leaseID = leaseID
        self.providerExecutionID = providerExecutionID
        self.acceptanceGeneration = acceptanceGeneration
        self.requestSequence = requestSequence
    }

    private init(canonicalSequenceZeroFrom validated: Self) {
        self.turnOperationRef = validated.turnOperationRef
        self.providerEgressBranchRef = validated.providerEgressBranchRef
        self.attemptRef = validated.attemptRef
        self.leaseID = validated.leaseID
        self.providerExecutionID = validated.providerExecutionID
        self.acceptanceGeneration = validated.acceptanceGeneration
        self.requestSequence = 0
    }

    /// Derives one event identity from the canonical sequence-zero base.
    public func withRequestSequence(
        _ requestSequence: UInt64
    ) throws -> Self {
        guard self.requestSequence == 0 else {
            throw BASProviderExecutionRefError.noncanonicalSequenceBase(
                found: self.requestSequence)
        }
        guard requestSequence > 0 else {
            throw BASProviderExecutionRefError.invalidRequestSequence
        }
        return try Self(
            validating: turnOperationRef,
            providerEgressBranchRef: providerEgressBranchRef,
            attemptRef: attemptRef,
            leaseID: leaseID,
            providerExecutionID: providerExecutionID,
            acceptanceGeneration: acceptanceGeneration,
            requestSequence: requestSequence)
    }

    /// Returns the exact six-field stable base for structural comparison.
    public func canonicalSequenceZeroBase() -> Self {
        requestSequence == 0
            ? self
            : Self(canonicalSequenceZeroFrom: self)
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.turnOperationRef == rhs.turnOperationRef
            && lhs.providerEgressBranchRef == rhs.providerEgressBranchRef
            && lhs.attemptRef == rhs.attemptRef
            && lhs.leaseID == rhs.leaseID
            && lhs.providerExecutionID.utf8.elementsEqual(
                rhs.providerExecutionID.utf8)
            && lhs.acceptanceGeneration == rhs.acceptanceGeneration
            && lhs.requestSequence == rhs.requestSequence
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(turnOperationRef)
        hasher.combine(providerEgressBranchRef)
        hasher.combine(attemptRef)
        hasher.combine(leaseID)
        hasher.combine(providerExecutionID.utf8.count)
        for byte in providerExecutionID.utf8 {
            hasher.combine(byte)
        }
        hasher.combine(acceptanceGeneration)
        hasher.combine(requestSequence)
    }

    private static func validate(
        turnOperationRef: BASTurnOperationRef,
        providerEgressBranchRef: BASTurnBranchRef,
        attemptRef: BASArtifactID,
        leaseID: BASArtifactID,
        providerExecutionID: String
    ) throws {
        guard providerEgressBranchRef.turnOperationRef == turnOperationRef else {
            throw BASProviderExecutionRefError.branchParentMismatch
        }
        guard providerEgressBranchRef.kind == .providerEgress else {
            throw BASProviderExecutionRefError.invalidBranchKind(
                found: providerEgressBranchRef.kind)
        }
        do {
            _ = try attemptRef.storageScalar
        } catch {
            throw BASProviderExecutionRefError.invalidArtifactID(
                field: "attemptRef")
        }
        do {
            _ = try leaseID.storageScalar
        } catch {
            throw BASProviderExecutionRefError.invalidArtifactID(
                field: "leaseID")
        }
        guard !providerExecutionID.isEmpty else {
            throw BASProviderExecutionRefError.invalidProviderExecutionID
        }
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case turnOperationRef
        case providerEgressBranchRef
        case attemptRef
        case leaseID
        case providerExecutionID
        case acceptanceGeneration
        case requestSequence
    }

    public init(from decoder: Decoder) throws {
        let wireContainer = try decoder.container(
            keyedBy: BASProviderExecutionRefWireCodingKey.self)
        let foundKeys = Set(wireContainer.allKeys.map(\.stringValue))
        let expectedKeys = Set(CodingKeys.allCases.map(\.rawValue))
        guard foundKeys == expectedKeys else {
            throw DecodingError.dataCorrupted(.init(
                codingPath: decoder.codingPath,
                debugDescription:
                    "BASProviderExecutionRef requires exactly seven keys"))
        }
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            validating: container.decode(
                BASTurnOperationRef.self,
                forKey: .turnOperationRef),
            providerEgressBranchRef: container.decode(
                BASTurnBranchRef.self,
                forKey: .providerEgressBranchRef),
            attemptRef: container.decode(
                BASArtifactID.self,
                forKey: .attemptRef),
            leaseID: container.decode(
                BASArtifactID.self,
                forKey: .leaseID),
            providerExecutionID: container.decode(
                String.self,
                forKey: .providerExecutionID),
            acceptanceGeneration: container.decode(
                UInt64.self,
                forKey: .acceptanceGeneration),
            requestSequence: container.decode(
                UInt64.self,
                forKey: .requestSequence))
    }
}

public enum BASProviderExecutionRefError: Error, Sendable, Equatable {
    case branchParentMismatch
    case invalidBranchKind(found: BASTurnBranchKind)
    case invalidArtifactID(field: String)
    case invalidProviderExecutionID
    case invalidRequestSequence
    case noncanonicalSequenceBase(found: UInt64)
}

private enum BASTurnLegacyProjectionDecodeError: Error {
    case malformedProjection
    case nonCanonicalProjection
}

private enum BASTurnLegacyProjectionDecoder {
    private static let maximumProjectionBytes = 4_096
    private static let maximumDecodedBytes = 3_072
    private static let maximumFieldCount = 5
    private static let maximumFieldBytes = 1_024

    static func decode(_ projection: String) throws -> [String] {
        guard !projection.isEmpty,
              projection.utf8.count <= maximumProjectionBytes,
              let data = Data(base64Encoded: projection),
              data.count <= maximumDecodedBytes
        else {
            throw BASTurnLegacyProjectionDecodeError.malformedProjection
        }
        guard data.base64EncodedString() == projection else {
            throw BASTurnLegacyProjectionDecodeError.nonCanonicalProjection
        }

        let bytes = Array(data)
        var fields: [String] = []
        var index = 0
        while index < bytes.count {
            guard fields.count < maximumFieldCount else {
                throw BASTurnLegacyProjectionDecodeError.malformedProjection
            }
            let digitStart = index
            var length = 0
            while index < bytes.count,
                  bytes[index] >= 48,
                  bytes[index] <= 57
            {
                guard index - digitStart < 4,
                      !(index > digitStart && bytes[digitStart] == 48)
                else {
                    throw BASTurnLegacyProjectionDecodeError
                        .malformedProjection
                }
                length = length * 10 + Int(bytes[index] - 48)
                index += 1
            }
            guard index > digitStart,
                  index < bytes.count,
                  bytes[index] == 58,
                  length <= maximumFieldBytes
            else {
                throw BASTurnLegacyProjectionDecodeError.malformedProjection
            }
            index += 1
            guard length <= bytes.count - index else {
                throw BASTurnLegacyProjectionDecodeError.malformedProjection
            }
            let end = index + length
            guard let field = String(bytes: bytes[index..<end], encoding: .utf8)
            else {
                throw BASTurnLegacyProjectionDecodeError.malformedProjection
            }
            fields.append(field)
            index = end
        }
        return fields
    }
}

// MARK: - Admission-time turn payloads

public enum BASTurnAdmissionPayloadError: Error, Sendable, Equatable {
    case invalidArtifactID(field: String)
    case selectedLineageTooLarge(actual: Int, maximum: Int)
    case duplicateSelectedLineageArtifactID
    case invalidBootSessionID
}

/// Immutable, unsigned facts admitted under one Artifact Mesh turn root.
public struct BASTurnOperationPayload:
    BASSchemaVersioned, Codable, Sendable, Hashable
{
    public static let currentSchemaVersion = "1.0.0"

    public let schemaVersion: String
    public let workspaceAuthorityArtifactID: BASArtifactID
    public let workspaceIncarnationArtifactID: BASArtifactID
    public let attemptRefArtifactID: BASArtifactID
    public let generationVectorArtifactID: BASArtifactID
    public let inputArtifactID: BASArtifactID
    public let budgetLeaseArtifactID: BASArtifactID
    public let orderedSelectedModelProfileLineageArtifactIDs: [BASArtifactID]
    public let policyEpoch: UInt64
    public let deletionEpoch: UInt64
    public let restorationEpoch: UInt64
    public let runtimeSchemaEpoch: UInt64

    public init(
        schemaVersion: String = Self.currentSchemaVersion,
        workspaceAuthorityArtifactID: BASArtifactID,
        workspaceIncarnationArtifactID: BASArtifactID,
        attemptRefArtifactID: BASArtifactID,
        generationVectorArtifactID: BASArtifactID,
        inputArtifactID: BASArtifactID,
        budgetLeaseArtifactID: BASArtifactID,
        orderedSelectedModelProfileLineageArtifactIDs: [BASArtifactID],
        policyEpoch: UInt64,
        deletionEpoch: UInt64,
        restorationEpoch: UInt64,
        runtimeSchemaEpoch: UInt64
    ) throws {
        let artifactFields: [(String, BASArtifactID)] = [
            ("workspaceAuthorityArtifactID", workspaceAuthorityArtifactID),
            ("workspaceIncarnationArtifactID", workspaceIncarnationArtifactID),
            ("attemptRefArtifactID", attemptRefArtifactID),
            ("generationVectorArtifactID", generationVectorArtifactID),
            ("inputArtifactID", inputArtifactID),
            ("budgetLeaseArtifactID", budgetLeaseArtifactID),
        ]
        for (field, artifactID) in artifactFields {
            try Self.validate(artifactID: artifactID, field: field)
        }
        guard orderedSelectedModelProfileLineageArtifactIDs.count
                <= Self.maximumSelectedLineageCount
        else {
            throw BASTurnAdmissionPayloadError.selectedLineageTooLarge(
                actual: orderedSelectedModelProfileLineageArtifactIDs.count,
                maximum: Self.maximumSelectedLineageCount)
        }
        for artifactID in orderedSelectedModelProfileLineageArtifactIDs {
            try Self.validate(
                artifactID: artifactID,
                field: "orderedSelectedModelProfileLineageArtifactIDs")
        }
        guard Set(orderedSelectedModelProfileLineageArtifactIDs).count
                == orderedSelectedModelProfileLineageArtifactIDs.count
        else {
            throw BASTurnAdmissionPayloadError
                .duplicateSelectedLineageArtifactID
        }

        self.schemaVersion = schemaVersion
        self.workspaceAuthorityArtifactID = workspaceAuthorityArtifactID
        self.workspaceIncarnationArtifactID = workspaceIncarnationArtifactID
        self.attemptRefArtifactID = attemptRefArtifactID
        self.generationVectorArtifactID = generationVectorArtifactID
        self.inputArtifactID = inputArtifactID
        self.budgetLeaseArtifactID = budgetLeaseArtifactID
        self.orderedSelectedModelProfileLineageArtifactIDs =
            orderedSelectedModelProfileLineageArtifactIDs
        self.policyEpoch = policyEpoch
        self.deletionEpoch = deletionEpoch
        self.restorationEpoch = restorationEpoch
        self.runtimeSchemaEpoch = runtimeSchemaEpoch
    }

    private static let maximumSelectedLineageCount = 64

    private static func validate(
        artifactID: BASArtifactID,
        field: String
    ) throws {
        do {
            _ = try artifactID.storageScalar
        } catch {
            throw BASTurnAdmissionPayloadError.invalidArtifactID(field: field)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case workspaceAuthorityArtifactID
        case workspaceIncarnationArtifactID
        case attemptRefArtifactID
        case generationVectorArtifactID
        case inputArtifactID
        case budgetLeaseArtifactID
        case orderedSelectedModelProfileLineageArtifactIDs
        case policyEpoch
        case deletionEpoch
        case restorationEpoch
        case runtimeSchemaEpoch
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            schemaVersion: container.decode(
                String.self, forKey: .schemaVersion),
            workspaceAuthorityArtifactID: container.decode(
                BASArtifactID.self, forKey: .workspaceAuthorityArtifactID),
            workspaceIncarnationArtifactID: container.decode(
                BASArtifactID.self, forKey: .workspaceIncarnationArtifactID),
            attemptRefArtifactID: container.decode(
                BASArtifactID.self, forKey: .attemptRefArtifactID),
            generationVectorArtifactID: container.decode(
                BASArtifactID.self, forKey: .generationVectorArtifactID),
            inputArtifactID: container.decode(
                BASArtifactID.self, forKey: .inputArtifactID),
            budgetLeaseArtifactID: container.decode(
                BASArtifactID.self, forKey: .budgetLeaseArtifactID),
            orderedSelectedModelProfileLineageArtifactIDs: container.decode(
                [BASArtifactID].self,
                forKey: .orderedSelectedModelProfileLineageArtifactIDs),
            policyEpoch: container.decode(UInt64.self, forKey: .policyEpoch),
            deletionEpoch: container.decode(
                UInt64.self, forKey: .deletionEpoch),
            restorationEpoch: container.decode(
                UInt64.self, forKey: .restorationEpoch),
            runtimeSchemaEpoch: container.decode(
                UInt64.self, forKey: .runtimeSchemaEpoch))
    }
}

/// The immutable ceiling bundle installed with the turn operation. Mutable
/// remaining/spent counters belong only to the selected K3 owner.
public struct BASBudgetLeasePayload:
    BASSchemaVersioned, Codable, Sendable, Hashable
{
    public static let currentSchemaVersion = "1.0.0"

    public let schemaVersion: String
    public let attemptRefArtifactID: BASArtifactID
    public let generationVectorArtifactID: BASArtifactID
    public let authorizationGrantArtifactID: BASArtifactID
    public let policyEpoch: UInt64
    public let deletionEpoch: UInt64
    public let bootSessionID: String
    public let tokenCeiling: UInt64
    public let byteCeiling: UInt64
    public let branchCeiling: UInt64
    public let remandRoundCeiling: UInt64
    public let hopCeiling: UInt64
    public let costMicrounitsCeiling: UInt64
    public let monotonicDeadlineNanos: UInt64

    public init(
        schemaVersion: String = Self.currentSchemaVersion,
        attemptRefArtifactID: BASArtifactID,
        generationVectorArtifactID: BASArtifactID,
        authorizationGrantArtifactID: BASArtifactID,
        policyEpoch: UInt64,
        deletionEpoch: UInt64,
        bootSessionID: String,
        tokenCeiling: UInt64,
        byteCeiling: UInt64,
        branchCeiling: UInt64,
        remandRoundCeiling: UInt64,
        hopCeiling: UInt64,
        costMicrounitsCeiling: UInt64,
        monotonicDeadlineNanos: UInt64
    ) throws {
        for (field, artifactID) in [
            ("attemptRefArtifactID", attemptRefArtifactID),
            ("generationVectorArtifactID", generationVectorArtifactID),
            ("authorizationGrantArtifactID", authorizationGrantArtifactID),
        ] {
            do {
                _ = try artifactID.storageScalar
            } catch {
                throw BASTurnAdmissionPayloadError.invalidArtifactID(
                    field: field)
            }
        }
        guard !bootSessionID.isEmpty,
              bootSessionID.utf8.count <= Self.maximumBootSessionIDBytes
        else {
            throw BASTurnAdmissionPayloadError.invalidBootSessionID
        }

        self.schemaVersion = schemaVersion
        self.attemptRefArtifactID = attemptRefArtifactID
        self.generationVectorArtifactID = generationVectorArtifactID
        self.authorizationGrantArtifactID = authorizationGrantArtifactID
        self.policyEpoch = policyEpoch
        self.deletionEpoch = deletionEpoch
        self.bootSessionID = bootSessionID
        self.tokenCeiling = tokenCeiling
        self.byteCeiling = byteCeiling
        self.branchCeiling = branchCeiling
        self.remandRoundCeiling = remandRoundCeiling
        self.hopCeiling = hopCeiling
        self.costMicrounitsCeiling = costMicrounitsCeiling
        self.monotonicDeadlineNanos = monotonicDeadlineNanos
    }

    private static let maximumBootSessionIDBytes = 256

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case attemptRefArtifactID
        case generationVectorArtifactID
        case authorizationGrantArtifactID
        case policyEpoch
        case deletionEpoch
        case bootSessionID
        case tokenCeiling
        case byteCeiling
        case branchCeiling
        case remandRoundCeiling
        case hopCeiling
        case costMicrounitsCeiling
        case monotonicDeadlineNanos
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            schemaVersion: container.decode(
                String.self, forKey: .schemaVersion),
            attemptRefArtifactID: container.decode(
                BASArtifactID.self, forKey: .attemptRefArtifactID),
            generationVectorArtifactID: container.decode(
                BASArtifactID.self, forKey: .generationVectorArtifactID),
            authorizationGrantArtifactID: container.decode(
                BASArtifactID.self, forKey: .authorizationGrantArtifactID),
            policyEpoch: container.decode(UInt64.self, forKey: .policyEpoch),
            deletionEpoch: container.decode(
                UInt64.self, forKey: .deletionEpoch),
            bootSessionID: container.decode(
                String.self, forKey: .bootSessionID),
            tokenCeiling: container.decode(UInt64.self, forKey: .tokenCeiling),
            byteCeiling: container.decode(UInt64.self, forKey: .byteCeiling),
            branchCeiling: container.decode(
                UInt64.self, forKey: .branchCeiling),
            remandRoundCeiling: container.decode(
                UInt64.self, forKey: .remandRoundCeiling),
            hopCeiling: container.decode(UInt64.self, forKey: .hopCeiling),
            costMicrounitsCeiling: container.decode(
                UInt64.self, forKey: .costMicrounitsCeiling),
            monotonicDeadlineNanos: container.decode(
                UInt64.self, forKey: .monotonicDeadlineNanos))
    }
}
