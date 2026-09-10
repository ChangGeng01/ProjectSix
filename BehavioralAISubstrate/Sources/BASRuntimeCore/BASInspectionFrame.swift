// MARK: - BASInspectionFrame
// chapter 五百七 / M1406 — 1st Tier C shape-specific
// generic primitive per ADR-019 (approved M1405)
//
// Generic shape DISTINCT from the 5 low-entropy
// primitives:
//
//   - BASBundle<Item> packs N homogeneous items + bundle
//     metadata
//   - BASResult<Body> wraps a success flag + body +
//     diagnostics
//   - BASCard<Kind, Body> tags a body with a typed kind
//     + headline + presentation hint
//   - BASFrameEnvelope<Body> pairs an immutable header
//     (schemaVersion + correlation ID + producer) with a
//     body
//   - BASPermit<Decision> wraps a typed decision with
//     permit metadata
//
// BASInspectionFrame<Body> targets the "inspection
// aggregate" shape:N inspector refs + N inspected
// refs + typed policy + timestamp + Body payload +
// diagnostics。 The existing BASInspectionBundle is the
// migration target per ADR-019。
//
// HONEST SCOPE — chapter 五百七:
// =============================================================
// This is the FIRST Tier C shape-specific generic
// primitive。 Pure-additive — does NOT migrate
// BASInspectionBundle yet (migration is follow-up arc
// work)。 V1 byte-equality preserved。 ADR-014 OPT-IN
// preserved (hosts that don't use Tier C primitives
// see no change)。

import Foundation

/// Generic inspection-aggregate envelope per ADR-019
/// approved chapter 五百七 M1405。
///
/// Carries:
///   - inspector refs (who is inspecting)
///   - inspected refs (what is being inspected)
///   - typed inspection policy
///   - inspection timestamp
///   - generic typed body payload
///   - ordered diagnostic codes
public struct BASInspectionFrame<Body>:
    Equatable, Hashable, Codable, Sendable
where
    Body: Equatable & Hashable & Codable & Sendable
{

    /// Stable identifier for this inspection event。
    public let inspectionID: String

    /// Schema version pin for replay-determinism。
    public let schemaVersion: String

    /// Stable refs to the inspector(s) performing the
    /// inspection。 Non-empty per inspection-doctrine
    /// pin (no anonymous inspections)。
    public let inspectorRefs: [String]

    /// Stable refs to the object(s) under inspection。
    public let inspectedRefs: [String]

    /// Typed inspection policy code (caller-defined
    /// taxonomy)。 Free-form String;policies SHOULD
    /// use stable IDs per chapter 一百八十五。
    public let inspectionPolicy: String

    /// Millis since epoch when the inspection was
    /// performed。
    public let inspectedAtMs: Int64

    /// Typed body payload。 Caller-defined shape per
    /// concrete instantiation。
    public let body: Body

    /// Ordered diagnostic codes in caller-defined
    /// taxonomy。 Empty when inspection passed cleanly;
    /// populated with reason codes on flags or failures。
    public let diagnostics: [String]

    public init(
        inspectionID: String,
        schemaVersion: String,
        inspectorRefs: [String],
        inspectedRefs: [String],
        inspectionPolicy: String,
        inspectedAtMs: Int64,
        body: Body,
        diagnostics: [String] = []
    ) {
        precondition(!inspectorRefs.isEmpty,
            "BASInspectionFrame inspectorRefs MUST be" +
            " non-empty (no anonymous inspections per" +
            " ADR-019 inspection-doctrine pin)")
        self.inspectionID = inspectionID
        self.schemaVersion = schemaVersion
        self.inspectorRefs = inspectorRefs
        self.inspectedRefs = inspectedRefs
        self.inspectionPolicy = inspectionPolicy
        self.inspectedAtMs = inspectedAtMs
        self.body = body
        self.diagnostics = diagnostics
    }

    // MARK: - Derived queries

    /// Whether the inspection completed without
    /// diagnostics (clean pass)。
    public var passed: Bool {
        diagnostics.isEmpty
    }

    /// Number of distinct inspectors who participated。
    public var distinctInspectorCount: Int {
        Set(inspectorRefs).count
    }

    /// Number of distinct objects inspected。
    public var distinctInspectedCount: Int {
        Set(inspectedRefs).count
    }
}
