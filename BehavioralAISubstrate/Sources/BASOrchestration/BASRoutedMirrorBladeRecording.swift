// MARK: - BASRoutedMirrorBladeRecording
// chapter 七百九十九 / M2646-M2650 — L7 mirror-blade recording activation
//
// Opt-in side channel that wires L7 decomposition outputs
// (chapter 七百六十四 mirror-blade + chapter 二百七十九 dissection
// frame) into the L7 storage adapters shipped at chapter 七百九十四:
//
//   - BASUnknownLedgerStore       (schema 011)
//   - BASContradictionLedgerStore (schema 012)
//
// Same pattern as `BASRoutedPresenceFusionRecording` (chapter 七百
// 九十八):the live L7 decomposition path is NOT modified — this
// file vends NEW recorder utilities hosts opt into when they want
// persistent ledgers attached to the in-memory dissection frames。
//
// ## Doctrine
//
// 「依旧 不删除 只 comment」 — `BASUnknownSet` + `BASContradictionRecord`
// stay in-memory by default。 Hosts that want the audit trail
// call `record...(...)` after each decomposition turn。
//
// ADR-014 OPT-IN — the storage adapters are addressable seams the
// host supplies。 Default substrate behavior is unchanged。
//
// ## Mapping decisions
//
// `BASUnknownSet` has FIVE typed string arrays (missingFacts,
// missingRoles,missingConstraints,unresolvedPermissions,
// ambiguityNotes)。 The L7 ledger schema (011) has a single
// `unknown_text` column。 To preserve the typed kind across the
// recording boundary,each emitted record is prefixed:
//
//   "fact: <text>"        for missingFacts
//   "role: <text>"        for missingRoles
//   "constraint: <text>"  for missingConstraints
//   "permission: <text>"  for unresolvedPermissions
//   "ambiguity: <text>"   for ambiguityNotes
//
// Ambiguity entries get a per-config lower default confidence
// (0.5) because they are softer signals than the four "missing"
// categories (which default to 1.0)。 Hosts can override either
// via `UnknownRecordingConfig`。
//
// `BASContradictionRecord.kind` (textual / historical / evidential
// / role) is folded into the text similarly:`"<kind>: <summary>"`
// so the L7 ledger row carries the discriminator without needing
// a schema column。 `severity` → schema `salience`,`unresolved`
// → schema `resolved` (inverted),`refs` joined into a parenthesized
// trailing suffix when non-empty。

import Foundation
import BASSovereign

public enum BASRoutedMirrorBladeRecording {

    // MARK: - Shared kind discriminator (chapter 八百二十一 dedup)

    /// Pinned 5-case enum mirroring the `BASUnknownSet` typed
    /// arrays。 Used as the single source of truth for the
    /// "<kind>: <text>" prefix encoding across recorder + replay
    /// + archive + aggregation。 Eliminates the 3-way duplication
    /// flagged by the chapter 八百二十一 全量 审查 review。
    public enum UnknownKind: String, Sendable, CaseIterable,
        Codable, Hashable
    {
        case fact
        case role
        case constraint
        case permission
        case ambiguity

        /// Schema-011-row prefix that flags this kind in the
        /// `unknown_text` column (e.g。 `"fact: "`)。
        public var prefix: String { "\(rawValue): " }
    }

    /// Strict prefix parser。 Returns the matched kind + the
    /// remaining body,or nil if no recognized prefix matches。
    /// Used by replay + archive + aggregation。
    ///
    /// ## Known lossy edge case (chapter 八百二十一 documented)
    ///
    /// If a user supplies a `missingFact` value that itself starts
    /// with another kind's prefix (e.g。 `missingFacts: ["role: missing actor"]`),
    /// replay will re-bucketize it AS `missingRoles: ["missing actor"]`。
    /// The encoder is intentionally textual + non-escaping for
    /// human-readability and SQLite full-text query friendliness。
    /// Hosts that need strict round-trip identity should treat
    /// `BASUnknownSet` string fields as「authored content,not
    /// machine-tokenized payload」 and avoid embedding `<kind>: `
    /// patterns at position 0 of their values。 The chapter 八百
    /// 二十一 review-remediation test demonstrates this edge case
    /// explicitly so hosts can see + acknowledge the constraint。
    public static func parseUnknownText(
        _ text: String
    ) -> (kind: UnknownKind, body: String)? {
        for kind in UnknownKind.allCases where text.hasPrefix(kind.prefix) {
            return (kind, String(text.dropFirst(kind.prefix.count)))
        }
        return nil
    }

    // MARK: - Configuration

    /// Per-category confidence + kind-prefix overrides for the
    /// unknown ledger recorder。 Defaults match the doctrine
    /// pinned in this file header。
    public struct UnknownRecordingConfig: Sendable {
        public var factConfidence: Double
        public var roleConfidence: Double
        public var constraintConfidence: Double
        public var permissionConfidence: Double
        public var ambiguityConfidence: Double

        public init(
            factConfidence: Double = 1.0,
            roleConfidence: Double = 1.0,
            constraintConfidence: Double = 1.0,
            permissionConfidence: Double = 1.0,
            ambiguityConfidence: Double = 0.5
        ) {
            self.factConfidence = clamp01(factConfidence)
            self.roleConfidence = clamp01(roleConfidence)
            self.constraintConfidence = clamp01(constraintConfidence)
            self.permissionConfidence = clamp01(permissionConfidence)
            self.ambiguityConfidence = clamp01(ambiguityConfidence)
        }
    }

    /// Configuration knobs for the contradiction recorder。
    public struct ContradictionRecordingConfig: Sendable {
        /// Confidence written for every record (severity drives
        /// the schema's salience field separately)。 Defaults to
        /// 1.0 because contradictions are emitted by the L7
        /// pipeline only after a hard textual / historical /
        /// evidential / role inconsistency is detected。
        public var defaultConfidence: Double
        /// When true,append " (refs: a, b, c)" to contradictionText
        /// for records that carry refs。 Default true so the trail
        /// stays self-contained without a separate join table。
        public var inlineRefs: Bool

        public init(
            defaultConfidence: Double = 1.0,
            inlineRefs: Bool = true
        ) {
            self.defaultConfidence = clamp01(defaultConfidence)
            self.inlineRefs = inlineRefs
        }
    }

    // MARK: - Unknown ledger recorder

    /// Flatten a `BASUnknownSet` into one ledger record per non-
    /// empty string across the 5 typed arrays。 Records carry the
    /// kind prefix described in the file header。 Returns the
    /// records written in insertion order (facts → roles →
    /// constraints → permissions → ambiguities)。
    ///
    /// - Parameters:
    ///   - set: the unknown set produced by L7 decomposition
    ///   - sessionID / turnID: schema-011 audit columns
    ///   - store: any conformer of `BASUnknownLedgerStore`
    ///   - eventIDPrefix: caller-supplied unique prefix
    ///   - nowMs: epoch ms written to discovered_at_ms
    ///   - config: per-category confidence overrides
    ///
    /// - Throws: if any append fails (caller must ensure prefix
    ///   uniqueness — duplicate-prefix collision surfaces as the
    ///   store's `duplicateEventID` error)
    @discardableResult
    public static func recordUnknownSet(
        _ set: BASUnknownSet,
        sessionID: String,
        turnID: String,
        store: BASUnknownLedgerStore,
        eventIDPrefix: String,
        nowMs: Int64,
        config: UnknownRecordingConfig = .init()
    ) async throws -> [BASUnknownLedgerRecord] {
        var written: [BASUnknownLedgerRecord] = []
        var idx = 0
        func appendBatch(
            _ items: [String],
            kindPrefix: String,
            confidence: Double
        ) async throws {
            for text in items {
                let record = BASUnknownLedgerRecord(
                    eventID: "\(eventIDPrefix)-\(idx)",
                    sessionID: sessionID,
                    turnID: turnID,
                    unknownText: "\(kindPrefix): \(text)",
                    confidence: confidence,
                    discoveredAtMs: nowMs)
                _ = try await store.appendRecord(record)
                written.append(record)
                idx += 1
            }
        }
        try await appendBatch(
            set.missingFacts,
            kindPrefix: "fact",
            confidence: config.factConfidence)
        try await appendBatch(
            set.missingRoles,
            kindPrefix: "role",
            confidence: config.roleConfidence)
        try await appendBatch(
            set.missingConstraints,
            kindPrefix: "constraint",
            confidence: config.constraintConfidence)
        try await appendBatch(
            set.unresolvedPermissions,
            kindPrefix: "permission",
            confidence: config.permissionConfidence)
        try await appendBatch(
            set.ambiguityNotes,
            kindPrefix: "ambiguity",
            confidence: config.ambiguityConfidence)
        return written
    }

    // MARK: - Contradiction ledger recorder

    /// Flatten an array of `BASContradictionRecord` into ledger
    /// records。 Schema-012's salience column is fed from
    /// `record.severity`,resolved/unresolved is inverted from
    /// `record.unresolved`,and the kind discriminator is folded
    /// into `contradictionText` as `"<kind>: <summary>"`。
    ///
    /// - Parameters:
    ///   - nodes: contradiction records produced by L7
    ///   - sessionID / turnID: schema-012 audit columns
    ///   - store: any conformer of `BASContradictionLedgerStore`
    ///   - eventIDPrefix: caller-supplied unique prefix
    ///   - nowMs: epoch ms used as resolved_at_ms IFF the
    ///     contradiction is already resolved at recording time
    ///     (`!record.unresolved`)
    ///   - config: text-formatting + default-confidence knobs
    @discardableResult
    public static func recordContradictions(
        _ nodes: [BASContradictionRecord],
        sessionID: String,
        turnID: String,
        store: BASContradictionLedgerStore,
        eventIDPrefix: String,
        nowMs: Int64,
        config: ContradictionRecordingConfig = .init()
    ) async throws -> [BASContradictionLedgerRecord] {
        var written: [BASContradictionLedgerRecord] = []
        for (idx, node) in nodes.enumerated() {
            var text = "\(node.kind.rawValue): \(node.summary)"
            if config.inlineRefs && !node.refs.isEmpty {
                text += " (refs: \(node.refs.joined(separator: ", ")))"
            }
            let resolved = !node.unresolved
            let record = BASContradictionLedgerRecord(
                eventID: "\(eventIDPrefix)-\(idx)",
                sessionID: sessionID,
                turnID: turnID,
                contradictionText: text,
                salience: clamp01(node.severity),
                confidence: config.defaultConfidence,
                resolved: resolved,
                resolvedAtMs: resolved ? nowMs : nil)
            _ = try await store.appendRecord(record)
            written.append(record)
        }
        return written
    }

    // MARK: - Replay helpers (chapter 八百九)

    /// Reconstruct a `BASUnknownSet` from previously persisted
    /// `BASUnknownLedgerRecord` rows。 Inverse of
    /// `recordUnknownSet(...)`:reads back the "<kind>: <text>"
    /// prefix encoding and bucketizes into the 5 typed arrays。
    ///
    /// Records whose unknownText doesn't match any of the 5
    /// kind prefixes are silently DROPPED (defensive — should
    /// not occur for valid persisted rows)。
    ///
    /// Order within each bucket follows the records' insertion
    /// order (chapter 七百九十四 store contract: ORDER BY
    /// discovered_at_ms ASC,rowid ASC)。
    public static func reconstructUnknownSet(
        from records: [BASUnknownLedgerRecord]
    ) -> BASUnknownSet {
        var facts: [String] = []
        var roles: [String] = []
        var constraints: [String] = []
        var permissions: [String] = []
        var ambiguities: [String] = []
        for record in records {
            // chapter 八百二十一: switched to shared parseUnknownText
            // helper (dedup with BASAuditTrailArchive +
            // BASRoutedAuditAggregation per 全量 审查 finding)。
            guard let parsed = parseUnknownText(record.unknownText)
            else { continue }
            switch parsed.kind {
            case .fact:        facts.append(parsed.body)
            case .role:        roles.append(parsed.body)
            case .constraint:  constraints.append(parsed.body)
            case .permission:  permissions.append(parsed.body)
            case .ambiguity:   ambiguities.append(parsed.body)
            }
        }
        return BASUnknownSet(
            missingFacts: facts,
            missingRoles: roles,
            missingConstraints: constraints,
            unresolvedPermissions: permissions,
            ambiguityNotes: ambiguities)
    }

    /// Reconstruct an array of `BASContradictionRecord` from
    /// persisted `BASContradictionLedgerRecord` rows。 Reverses
    /// the "<kind>: <summary>" / " (refs: a, b, c)" encoding。
    ///
    /// Records whose `contradictionText` doesn't carry a valid
    /// `BASContradictionKind` prefix are silently DROPPED。
    ///
    /// Order follows the records' insertion order。
    public static func reconstructContradictions(
        from records: [BASContradictionLedgerRecord]
    ) -> [BASContradictionRecord] {
        var nodes: [BASContradictionRecord] = []
        for (idx, record) in records.enumerated() {
            guard let parsed = parseContradictionText(
                record.contradictionText)
            else { continue }
            nodes.append(BASContradictionRecord(
                nodeID: "replay-\(idx)",
                kind: parsed.kind,
                summary: parsed.summary,
                refs: parsed.refs,
                severity: record.salience,
                unresolved: !record.resolved))
        }
        return nodes
    }

    /// Parse the "<kind>: <summary>" + optional " (refs: ...)"
    /// encoding。 Returns nil if no valid kind prefix matches。
    static func parseContradictionText(
        _ text: String
    ) -> (kind: BASContradictionKind, summary: String, refs: [String])? {
        for kind in BASContradictionKind.allCases {
            let prefix = "\(kind.rawValue): "
            guard text.hasPrefix(prefix) else { continue }
            let body = String(text.dropFirst(prefix.count))
            // Split off optional " (refs: ...)" suffix
            let refsMarker = " (refs: "
            if let range = body.range(of: refsMarker),
               body.hasSuffix(")") {
                let summary = String(body[..<range.lowerBound])
                let refsBody = body[range.upperBound..<body.index(before: body.endIndex)]
                let refs = refsBody.split(separator: ", ")
                    .map { String($0) }
                return (kind, summary, refs)
            }
            return (kind, body, [])
        }
        return nil
    }
}

// MARK: - Helpers

private func clamp01(_ x: Double) -> Double {
    return min(max(x, 0), 1)
}

private func stripped(_ s: String, prefix: String) -> String? {
    if s.hasPrefix(prefix) {
        return String(s.dropFirst(prefix.count))
    }
    return nil
}
