// MARK: - BASMeshSyncFrame — chapter 三百一八 / M805
//
// Phase Epsilon 第五刀:cross-instance mesh sync foundation。
// v9 manifesto §8 listed "Cross-instance / multi-host mesh
// synchronization" as explicit external work — no doctrine yet
// existed for sharing slot bindings across instances。This chapter
// closes that gap at the schema layer (typed sync frame) without
// committing to a wire protocol or a transport。
//
// ## What "cross-instance mesh sync" means
//
// Each `BASLayerMLHeadRegistry` actor owns its own slot list。
// In multi-host or multi-device deployments,instances may want
// to share which heads are registered (e.g. roll out a new
// CoreML head version to all devices,or audit which devices
// have outdated mesh shapes)。
//
// chapter 一百九十一 (M91) shipped `BASSovereignAuditLedgerSegment`
// for cross-process audit ledger sync。chapter 一百二十七 (M329)
// shipped `BASSovereignFragmentMerger` for cross-device ledger
// merging。This chapter follows the same pattern for ML head
// mesh: typed sync frame + merge semantics defined,wire protocol
// + transport left to host implementation。
//
// ## What this ships
//
// 3 typed primitives:
//
//   - `BASMeshSyncFrame` (BASSchemaVersioned 1.0.0) — typed
//     export frame describing one instance's full slot inventory
//     at a point in time: instanceID + emittedAt + slotCount +
//     slotsByLayer (snapshot of registry state) + signature
//   - `BASMeshSyncFrameDoctrine` enum — typed merge resolution
//     rules: noOp / preferRemote / preferLocal / sovereignReview
//   - `BASMeshSyncFrameMergeReport` — typed merge result:
//     conflictCount + appliedCount + skippedCount + reasonCodes
//
// ## What this does NOT ship
//
// - No transport (TCP / Bluetooth / iCloud sync etc.)
// - No conflict-resolution algorithm beyond the typed doctrine enum
// - No multi-instance coordination protocol
//
// These remain explicit external work. Hosts that want to wire
// transport call this typed layer to derive the sync frames +
// apply the merge — the typed contract is sufficient for hosts
// to write transport-specific code without re-inventing schema.
//
// ## Doctrine pins held
//
//   - 不变量 #1 / #2 / #3 全保 — sync frame is observability
//     metadata, doesn't mutate weight or verdict authority
//   - 红线 7 watcher hint only — sync frame describes hint-class
//     ML head bindings, never permit/warrant authority
//   - 单提交口 (L11/L14) 不变 — sync doesn't issue permits;
//     `.sovereignReview` doctrine flags conflicts requiring L14
//     warrant
//   - chapter 二百一一 single-source-of-truth: typed sync frame
//     IS the canonical export shape (vs scattered ad-hoc syncs)
//   - chapter 一百八十五 anti-magic-number: 4-case doctrine enum,
//     all merge rules typed
//   - chapter 一百三 schema-version: 1.0.0 invariant
//   - chapter 一百三十 BASLearnabilityClass: sync frame is
//     observability metadata, semi-learnable
//   - chapter 一百九十一 M91 + chapter 一百二十七 M329 cross-
//     process / cross-device sync precedent: this chapter
//     follows the same typed-frame + transport-deferred pattern
//   - chapter 三百一〇 BASLayerMLHeadRegistry: sync frames
//     describe registry state at a specific instance + moment

import Foundation

// MARK: - Merge doctrine taxonomy

/// 4-case typed enum for cross-instance mesh sync merge rules。
/// Lets hosts choose how to resolve slot binding conflicts when
/// importing a remote sync frame。
public enum BASMeshSyncFrameDoctrine:
    String,
    Sendable,
    Equatable,
    Hashable,
    Codable,
    CaseIterable
{
    /// Don't merge anything — record the frame for diagnostic
    /// audit only. Local registry stays unchanged.
    case noOp = "no-op"

    /// On conflict, prefer remote slot binding. Local is
    /// overwritten. Use this for "centralized config push"
    /// deployments.
    case preferRemote = "prefer-remote"

    /// On conflict, prefer local slot binding. Remote is
    /// ignored. Use this for "edge instances are authoritative"
    /// deployments (e.g. iPhone is canonical, server syncs FROM
    /// iPhone).
    case preferLocal = "prefer-local"

    /// On conflict, flag for L14 sovereign review. Caller writes
    /// audit entry + waits for warrant before applying. Use this
    /// for high-stakes deployments where mesh changes require
    /// human verification.
    case sovereignReview = "sovereign-review"
}

// MARK: - Sync frame

/// Typed export frame describing one instance's full slot
/// inventory at a point in time。Immutable once emitted。
///
/// Field semantics:
///   - `instanceID` — stable identifier for the emitting
///     `BASLayerMLHeadRegistry` (caller assigns at registry
///     construction;e.g. device ID + runtime ID combo)
///   - `schemaVersion` — sync frame schema version (this is the
///     OUTER schema; individual slot records have their own
///     schema versions)
///   - `emittedAt` — wall-clock time the frame was generated
///   - `slotsByLayer` — per-layer snapshot of slot bindings;
///     full registry state at emit time. Keys are
///     `BASMotherboardLayer14.rawValue` strings (Codable-friendly
///     vs `[BASMotherboardLayer14: [BASLayerMLHeadSlot]]` which
///     requires custom Codable).
///   - `signature` — optional opaque signature string for
///     authenticity check (HMAC / Ed25519 / etc); caller-defined
///     scheme. nil for unsigned/dev frames.
public struct BASMeshSyncFrame:
    BASSchemaVersioned,
    Sendable,
    Equatable,
    Hashable,
    Codable
{
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var instanceID: String
    public var emittedAt: Date
    public var slotsByLayer: [String: [BASLayerMLHeadSlot]]
    public var signature: String?

    public init(
        schemaVersion: String
            = BASMeshSyncFrame.currentSchemaVersion,
        instanceID: String,
        emittedAt: Date,
        slotsByLayer: [String: [BASLayerMLHeadSlot]] = [:],
        signature: String? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.instanceID = instanceID
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.emittedAt = emittedAt
        self.slotsByLayer = slotsByLayer
        self.signature = signature?
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

public extension BASMeshSyncFrame {
    /// Total slot count across all layers in this frame。
    var totalSlotCount: Int {
        slotsByLayer.values.reduce(0) { $0 + $1.count }
    }

    /// Sorted slot list for a specific layer, or empty if absent。
    func slots(
        forLayer layerID: BASMotherboardLayer14
    ) -> [BASLayerMLHeadSlot] {
        slotsByLayer[layerID.rawValue] ?? []
    }

    /// Build a sync frame snapshot from a registry's current state。
    /// Caller-supplied `instanceID` + `emittedAt` (clock seam) +
    /// optional signature。
    static func snapshot(
        registry: BASLayerMLHeadRegistry,
        instanceID: String,
        emittedAt: Date,
        signature: String? = nil
    ) async -> BASMeshSyncFrame {
        var slotsByLayer: [String: [BASLayerMLHeadSlot]] = [:]
        for layer in BASMotherboardLayer14.allCases {
            let slots = await registry.slots(forLayer: layer)
            if !slots.isEmpty {
                slotsByLayer[layer.rawValue] = slots
            }
        }
        return BASMeshSyncFrame(
            instanceID: instanceID,
            emittedAt: emittedAt,
            slotsByLayer: slotsByLayer,
            signature: signature)
    }
}

// MARK: - Merge report

/// Typed result of applying a sync frame to a local registry。
/// Records what changed + emits typed reason codes for audit
/// emission。
public struct BASMeshSyncFrameMergeReport:
    BASSchemaVersioned, Sendable, Equatable, Codable
{
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String

    /// Doctrine applied to resolve conflicts.
    public var doctrineApplied: BASMeshSyncFrameDoctrine

    /// Slots in remote frame that successfully merged into local.
    public var appliedCount: Int

    /// Slots skipped (already present locally + doctrine ==
    /// `.preferLocal`, or doctrine == `.noOp`, etc.)
    public var skippedCount: Int

    /// Conflicts encountered (slot exists in both with different
    /// metadata). Always reported regardless of doctrine.
    public var conflictCount: Int

    /// Slots flagged for sovereign review (only > 0 when
    /// doctrine == `.sovereignReview`).
    public var sovereignReviewCount: Int

    public var reasonCodes: [String]

    public init(
        schemaVersion: String
            = BASMeshSyncFrameMergeReport.currentSchemaVersion,
        doctrineApplied: BASMeshSyncFrameDoctrine,
        appliedCount: Int = 0,
        skippedCount: Int = 0,
        conflictCount: Int = 0,
        sovereignReviewCount: Int = 0,
        reasonCodes: [String] = []
    ) {
        self.schemaVersion = schemaVersion
        self.doctrineApplied = doctrineApplied
        self.appliedCount = max(0, appliedCount)
        self.skippedCount = max(0, skippedCount)
        self.conflictCount = max(0, conflictCount)
        self.sovereignReviewCount = max(0, sovereignReviewCount)
        self.reasonCodes = reasonCodes
            .map { $0.trimmingCharacters(
                in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}

public extension BASMeshSyncFrameMergeReport {
    /// Build typed reason codes describing the merge outcome。
    static func makeReasonCodes(
        doctrine: BASMeshSyncFrameDoctrine,
        applied: Int,
        skipped: Int,
        conflicts: Int,
        sovereignReview: Int,
        remoteInstanceID: String
    ) -> [String] {
        var codes: [String] = [
            "mesh-sync:doctrine:\(doctrine.rawValue)",
            "mesh-sync:remote-instance:\(remoteInstanceID)",
            "mesh-sync:applied:\(applied)",
            "mesh-sync:skipped:\(skipped)",
            "mesh-sync:conflicts:\(conflicts)"
        ]
        if sovereignReview > 0 {
            codes.append(
                "mesh-sync:sovereign-review:\(sovereignReview)")
        }
        return codes
    }
}
