import Foundation

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
}
