import Foundation
import BASRuntimeCore
import BASSovereign

extension QinaoSovereignControlPlane {

    // MARK: - M83 audit-trail rotation + LINEAGE_CUT
    //
    // Public value types describing audit-trail segment rotation
    // and lineage-cut outcomes. The actor's `rotateAuditTrail` /
    // `cutLineage` methods (which touch ledger state) stay on the
    // primary `QinaoSovereign.swift` body.

    /// Why a trail segment was closed.
    public enum TrailRotationReason: String, Sendable, Equatable,
        Codable, CaseIterable
    {
        case scheduledRotation
        case sessionClosure
        case lineageCut
        case integrityRebaseline
        case explicitOperator
    }

    /// Public descriptor of one closed (or currently-open)
    /// audit-trail segment. A segment is one contiguous
    /// hash-chained run; rotation produces a sequence.
    public struct TrailSegment: Sendable, Equatable, Codable {
        public let segmentID: String
        /// 0 for genesis; increments by one per rotation within
        /// the session.
        public let segmentIndex: Int
        public let sessionID: String
        /// Opaque anchor — preceding segment's tail hash, or the
        /// literal `"GENESIS"` sentinel for segment 0.
        public let startAnchor: String
        /// Opaque tail hash, or `nil` while the segment is open.
        public let tailHash: String?
        public let entryCount: Int
        public let openedAt: Date
        public let closedAt: Date?
        public let closedBy: TrailRotationReason?
        /// Rotation ID that closed this segment, if any.
        public let closingRotationID: String?

        public init(
            segmentID: String,
            segmentIndex: Int,
            sessionID: String,
            startAnchor: String,
            tailHash: String? = nil,
            entryCount: Int = 0,
            openedAt: Date,
            closedAt: Date? = nil,
            closedBy: TrailRotationReason? = nil,
            closingRotationID: String? = nil
        ) {
            self.segmentID = segmentID
            self.segmentIndex = segmentIndex
            self.sessionID = sessionID
            self.startAnchor = startAnchor
            self.tailHash = tailHash
            self.entryCount = entryCount
            self.openedAt = openedAt
            self.closedAt = closedAt
            self.closedBy = closedBy
            self.closingRotationID = closingRotationID
        }

        public var isClosed: Bool { tailHash != nil }
    }

    /// How deep a LINEAGE_CUT cascades through audit references.
    public enum LineageCutDepth: Sendable, Equatable, Codable {
        /// Only the root audit ref. No cascade.
        case root
        /// Root plus up to `hops` levels of downstream citations.
        /// `hops < 0` is clamped to 0.
        case bounded(hops: Int)
        /// Cascade until fixpoint.
        case entireLineage
    }

    /// Outcome of a sovereign-approved lineage cut.
    public struct LineageCutOutcome: Sendable, Equatable, Codable {
        public let cutID: String
        public let sessionID: String
        /// Audit refs the cascade concluded were downstream of
        /// the root and should be cut.
        public let affectedAuditRefs: [String]
        /// Audit refs the cascade reached but preserved because
        /// their rule set intersected the request's
        /// protected-rules set.
        public let protectedAuditRefs: [String]
        /// Audit ref of the cut-marker entry itself.
        public let markerAuditRef: String
        /// Segment that the cut closed.
        public let closedSegment: TrailSegment
        /// Rotation ID the cut generated internally.
        public let rotationID: String
        public let completedAt: Date

        public init(
            cutID: String,
            sessionID: String,
            affectedAuditRefs: [String],
            protectedAuditRefs: [String],
            markerAuditRef: String,
            closedSegment: TrailSegment,
            rotationID: String,
            completedAt: Date
        ) {
            self.cutID = cutID
            self.sessionID = sessionID
            self.affectedAuditRefs = affectedAuditRefs
            self.protectedAuditRefs = protectedAuditRefs
            self.markerAuditRef = markerAuditRef
            self.closedSegment = closedSegment
            self.rotationID = rotationID
            self.completedAt = completedAt
        }
    }

    /// Errors surfaced by rotation and lineage-cut operations.
    public enum TrailError: Error, Equatable, Sendable {
        /// Session has no open segment to rotate.
        case noOpenSegment(sessionID: String)
        /// LINEAGE_CUT referenced an audit ref absent from the
        /// trail.
        case lineageRootNotFound(auditRef: String)
        case invalidRequest(String)
        /// Trail operations refused while the session is halted —
        /// prevents a compromised session from trimming its own
        /// lineage.
        case sessionHalted(sessionID: String)
    }

    /// Close the currently-open segment so subsequent appends
    /// start a fresh successor anchored to the closed tail.
    /// Halted sessions refuse rotation. BR-012-safe: no
    /// hash-chain content is modified, only segment-boundary
    /// bookkeeping.
    @discardableResult
    public func rotateAuditTrail(
        sessionID: String,
        reason: TrailRotationReason = .scheduledRotation,
        rotationID: String? = nil
    ) async throws -> TrailSegment {
        if haltedSessions.contains(sessionID) {
            throw TrailError.sessionHalted(sessionID: sessionID)
        }
        let plan = BASSovereignLedgerRotationPlan(
            rotationID: rotationID
                ?? "rot-\(UUID().uuidString)",
            sessionID: sessionID,
            beforeTurnID: nil,
            reason: Self.toBASRotationReason(reason),
            requestedAt: now())
        do {
            let closed = try await auditLedger.rotate(plan: plan)
            return Self.externalize(closed)
        } catch BASSovereignAuditLedger.LedgerError.noOpenSegment(
            let session)
        {
            throw TrailError.noOpenSegment(sessionID: session)
        }
    }

    /// Apply a sovereign-approved LINEAGE_CUT. Cascades downstream
    /// from `rootAuditRef` up to `depth`, skipping (and halting
    /// at) entries whose rule set intersects `protectedRuleIDs`.
    /// Writes a hash-chained marker entry and rotates the segment
    /// so the marker becomes the closing tail. BR-012-safe: no
    /// audit entry is deleted; the cut records sovereign intent
    /// to propagate removal to *downstream consumers*.
    @discardableResult
    public func cutLineage(
        cutID: String,
        sessionID: String,
        rootAuditRef: String,
        depth: LineageCutDepth = .entireLineage,
        reason: String,
        protectedRuleIDs: Set<String> = []
    ) async throws -> LineageCutOutcome {
        if haltedSessions.contains(sessionID) {
            throw TrailError.sessionHalted(sessionID: sessionID)
        }
        guard !cutID.isEmpty else {
            throw TrailError.invalidRequest("cutID must be non-empty")
        }
        guard !sessionID.isEmpty else {
            throw TrailError.invalidRequest("sessionID must be non-empty")
        }
        guard !rootAuditRef.isEmpty else {
            throw TrailError.invalidRequest(
                "rootAuditRef must be non-empty")
        }
        let request = BASSovereignLineageCutRequest(
            cutID: cutID,
            sessionID: sessionID,
            rootAuditID: rootAuditRef,
            depth: Self.toBASDepth(depth),
            reason: reason,
            protectedRuleIDs: protectedRuleIDs,
            requestedAt: now())
        do {
            let outcome = try await auditLedger.lineageCut(
                request: request)
            let segs = await auditLedger.segments(
                forSession: sessionID)
            let closed = segs.first {
                $0.closingRotationID == outcome.rotation.rotationID
            }
            guard let closed else {
                // Defensive — lineageCut always rotates.
                throw TrailError.invalidRequest(
                    "lineageCut produced no closing segment")
            }
            return LineageCutOutcome(
                cutID: outcome.cutID,
                sessionID: outcome.sessionID,
                affectedAuditRefs: outcome.affectedAuditIDs,
                protectedAuditRefs: outcome.protectedAuditIDs,
                markerAuditRef: outcome.markerAuditID,
                closedSegment: Self.externalize(closed),
                rotationID: outcome.rotation.rotationID,
                completedAt: outcome.completedAt)
        } catch BASSovereignAuditLedger.LedgerError
            .lineageRootNotFound(let id)
        {
            throw TrailError.lineageRootNotFound(auditRef: id)
        } catch BASSovereignAuditLedger.LedgerError.invalidEntry(let msg) {
            throw TrailError.invalidRequest(msg)
        }
    }

    /// Currently-open segment, or nil when none.
    public func currentAuditSegment(
        sessionID: String
    ) async -> TrailSegment? {
        await auditLedger.currentSegment(forSession: sessionID)
            .map(Self.externalize)
    }

    /// All segments for a session in creation order.
    public func auditSegments(
        sessionID: String
    ) async -> [TrailSegment] {
        await auditLedger.segments(forSession: sessionID)
            .map(Self.externalize)
    }

    /// Look up a previously-applied cut by marker audit ref.
    public func lineageCutOutcome(
        markerAuditRef: String
    ) async -> LineageCutOutcome? {
        guard let bas = await auditLedger.lineageCutOutcome(
            markerAuditID: markerAuditRef)
        else { return nil }
        let segs = await auditLedger.segments(
            forSession: bas.sessionID)
        let closed = segs.first {
            $0.closingRotationID == bas.rotation.rotationID
        }
        guard let closed else { return nil }
        return LineageCutOutcome(
            cutID: bas.cutID,
            sessionID: bas.sessionID,
            affectedAuditRefs: bas.affectedAuditIDs,
            protectedAuditRefs: bas.protectedAuditIDs,
            markerAuditRef: bas.markerAuditID,
            closedSegment: Self.externalize(closed),
            rotationID: bas.rotation.rotationID,
            completedAt: bas.completedAt)
    }
}
