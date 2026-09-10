// MARK: - BASMeshSyncFrameApplier — chapter 三百三六 / M823 (residual #5)
//
// Closes the **in-repo portion** of v9 §8 non-promise #5
// (Cross-instance / multi-host mesh sync transport)。
//
// chapter 三百一九 (M805) shipped `BASMeshSyncFrame` schema +
// `BASMeshSyncFrameDoctrine` resolution rules + `BAS
// MeshSyncFrameMergeReport` typed report — but no applier。
// Hosts had a frame-shape with no way to actually compare it
// against a local registry。
//
// This namespace ships the **doctrine-respecting diff helper**:
// computes what WOULD change if a remote frame were merged into
// a local registry under each typed doctrine,WITHOUT mutating
// state。Hosts use the report to:
//   - audit-emit the proposed delta
//   - drive an L14 sovereign-review flow when doctrine ==
//     `.sovereignReview`
//   - decide their own application strategy (transport-agnostic)
//
// **Out of scope (preserved as honest external boundaries)**:
//   - Network / file / iCloud / Bluetooth transport — hosts wire
//     their own
//   - Actual mutation of the registry — applier is dry-run only
//     (the v1 contract)
//   - Conflict-resolution algorithms beyond the typed doctrine
//     enum (preferRemote / preferLocal / sovereignReview / noOp)
//   - Multi-instance coordination protocol (e.g. CRDTs, vector
//     clocks)
//
// ## Doctrine pins held
//
//   - 不变量 #1 / #2 / #3 全保 — applier is read-only,no
//     decision path mutation
//   - 红线 7 watcher hint only — diff report is observability
//     metadata only
//   - 单提交口 (L11/L14) 不变 — applier does NOT issue permits;
//     `.sovereignReview` doctrine flags slots for caller to
//     consult L14 warrant flow separately
//   - chapter 二百一一 single-source-of-truth: ONE applier
//     namespace,no scattered sync-comparison code
//   - chapter 一百八十五 anti-magic-number: doctrine raw values
//     typed-pinned by `BASMeshSyncFrameDoctrine` enum
//   - chapter 三百三二 reality-check pattern: applier returns
//     typed report;real-world transport integration tests
//     are explicit external work hosts wire themselves

import Foundation

/// Typed namespace for mesh sync frame diff + dry-run merge
/// helpers。
public enum BASMeshSyncFrameApplier {

    // MARK: - Conflict classification

    /// Typed classifier for slot-by-slot diff outcomes when
    /// comparing remote frame to local registry slots。
    public enum SlotConflict:
        String, Sendable, Equatable, Hashable, Codable,
        CaseIterable
    {
        /// Slot present in remote frame but headID NOT in
        /// local registry。Cannot apply (no head instance to
        /// bind to);recorded for audit。
        case remoteHasUnknownHead = "remote-has-unknown-head"

        /// Slot in both;identical priority + enabled state。
        /// No diff,no action needed。
        case identical = "identical"

        /// Slot in both;priority differs。
        case priorityDiffers = "priority-differs"

        /// Slot in both;enabled state differs。
        case enabledDiffers = "enabled-differs"

        /// Slot in both;both priority AND enabled differ。
        case priorityAndEnabledDiffer =
            "priority-and-enabled-differ"

        /// Slot in local registry but absent from remote frame。
        /// (Local has more than remote。)
        case localOnly = "local-only"
    }

    /// Per-slot diff entry with typed conflict classification +
    /// the local + remote slot records (when present)。
    public struct SlotDiff:
        Sendable, Equatable, Codable
    {
        public let conflict: SlotConflict
        public let headID: String
        public let layerID: BASMotherboardLayer14
        public let localSlot: BASLayerMLHeadSlot?
        public let remoteSlot: BASLayerMLHeadSlot?

        public init(
            conflict: SlotConflict,
            headID: String,
            layerID: BASMotherboardLayer14,
            localSlot: BASLayerMLHeadSlot?,
            remoteSlot: BASLayerMLHeadSlot?
        ) {
            self.conflict = conflict
            self.headID = headID
            self.layerID = layerID
            self.localSlot = localSlot
            self.remoteSlot = remoteSlot
        }
    }

    // MARK: - Dry-run diff entry point

    /// Compute slot-by-slot diff between a remote sync frame
    /// and a local registry's enabled+priority state。Returns
    /// typed diff list — caller decides what to do with it。
    ///
    /// **Read-only**:does NOT mutate the registry。
    ///
    /// - Parameters:
    ///   - registry: local `BASLayerMLHeadRegistry` actor (read-
    ///     only access via `allSlots`)
    ///   - frame: remote `BASMeshSyncFrame` produced by another
    ///     instance
    /// - Returns: list of typed `SlotDiff` entries covering all
    ///   slot keys in either side
    public static func diff(
        local: BASLayerMLHeadRegistry,
        remote frame: BASMeshSyncFrame
    ) async -> [SlotDiff] {
        let localSlots = await registrySlotMap(
            registry: local)
        let remoteSlots = remoteSlotMap(frame: frame)
        return computeDiff(
            localSlots: localSlots,
            remoteSlots: remoteSlots,
            knownHeadIDs: await registryKnownHeadIDs(
                registry: local))
    }

    /// Convenience wrapper that returns a typed merge report
    /// describing what the caller-supplied doctrine WOULD do。
    /// Read-only;does NOT mutate the registry。
    public static func dryRunMerge(
        local: BASLayerMLHeadRegistry,
        remote frame: BASMeshSyncFrame,
        doctrine: BASMeshSyncFrameDoctrine
    ) async -> BASMeshSyncFrameMergeReport {
        let diffs = await diff(local: local, remote: frame)
        return makeMergeReport(
            diffs: diffs,
            doctrine: doctrine,
            instanceID: frame.instanceID)
    }

    // MARK: - Internal helpers

    private static func registrySlotMap(
        registry: BASLayerMLHeadRegistry
    ) async -> [String: BASLayerMLHeadSlot] {
        let all = await registry.allSlots
        var map: [String: BASLayerMLHeadSlot] = [:]
        for slot in all {
            map[slot.headID] = slot
        }
        return map
    }

    private static func registryKnownHeadIDs(
        registry: BASLayerMLHeadRegistry
    ) async -> Set<String> {
        let all = await registry.allSlots
        return Set(all.map { $0.headID })
    }

    private static func remoteSlotMap(
        frame: BASMeshSyncFrame
    ) -> [String: BASLayerMLHeadSlot] {
        var map: [String: BASLayerMLHeadSlot] = [:]
        for (_, list) in frame.slotsByLayer {
            for slot in list {
                map[slot.headID] = slot
            }
        }
        return map
    }

    private static func computeDiff(
        localSlots: [String: BASLayerMLHeadSlot],
        remoteSlots: [String: BASLayerMLHeadSlot],
        knownHeadIDs: Set<String>
    ) -> [SlotDiff] {
        var diffs: [SlotDiff] = []

        // Walk remote slots
        for (headID, remoteSlot) in remoteSlots {
            if let localSlot = localSlots[headID] {
                let priorityDiff =
                    localSlot.priority != remoteSlot.priority
                let enabledDiff =
                    localSlot.enabled != remoteSlot.enabled
                let conflict: SlotConflict
                if priorityDiff && enabledDiff {
                    conflict = .priorityAndEnabledDiffer
                } else if priorityDiff {
                    conflict = .priorityDiffers
                } else if enabledDiff {
                    conflict = .enabledDiffers
                } else {
                    conflict = .identical
                }
                diffs.append(SlotDiff(
                    conflict: conflict,
                    headID: headID,
                    layerID: localSlot.layerID,
                    localSlot: localSlot,
                    remoteSlot: remoteSlot))
            } else {
                // Remote has a slot we don't know about
                diffs.append(SlotDiff(
                    conflict: .remoteHasUnknownHead,
                    headID: headID,
                    layerID: remoteSlot.layerID,
                    localSlot: nil,
                    remoteSlot: remoteSlot))
            }
        }

        // Walk local-only slots
        for (headID, localSlot) in localSlots {
            if remoteSlots[headID] == nil {
                diffs.append(SlotDiff(
                    conflict: .localOnly,
                    headID: headID,
                    layerID: localSlot.layerID,
                    localSlot: localSlot,
                    remoteSlot: nil))
            }
        }

        // Stable ordering: by headID lexicographic
        return diffs.sorted { $0.headID < $1.headID }
    }

    private static func makeMergeReport(
        diffs: [SlotDiff],
        doctrine: BASMeshSyncFrameDoctrine,
        instanceID: String
    ) -> BASMeshSyncFrameMergeReport {
        var appliedCount = 0
        var skippedCount = 0
        var conflictCount = 0
        var sovereignReviewCount = 0
        var reasonCodes: [String] = [
            "mesh-sync:doctrine:\(doctrine.rawValue)",
            "mesh-sync:remote-instance:\(instanceID)",
            "mesh-sync:diff-count:\(diffs.count)"
        ]

        for diff in diffs {
            switch diff.conflict {
            case .identical:
                // Chapter 三百三七 / M824 fix: deep review
                // caught that `.identical` slots silently
                // bumped `appliedCount`,conflating "would be
                // applied" with "no change needed"。Hosts
                // reading appliedCount couldn't distinguish。
                //
                // Fix: still bump appliedCount (preserves the
                // schema contract — applied means converged
                // state),BUT also emit an explicit reason
                // code distinguishing this from real
                // "applied-from-remote" cases。
                appliedCount += 1
                reasonCodes.append(
                    "mesh-sync:no-change:\(diff.headID)")
            case .remoteHasUnknownHead:
                skippedCount += 1
                reasonCodes.append(
                    "mesh-sync:skip:\(diff.headID):" +
                    "unknown-head")
            case .localOnly:
                skippedCount += 1
                reasonCodes.append(
                    "mesh-sync:skip:\(diff.headID):" +
                    "local-only")
            case .priorityDiffers, .enabledDiffers,
                 .priorityAndEnabledDiffer:
                conflictCount += 1
                switch doctrine {
                case .noOp:
                    skippedCount += 1
                    reasonCodes.append(
                        "mesh-sync:noop:\(diff.headID)")
                case .preferRemote:
                    appliedCount += 1
                    reasonCodes.append(
                        "mesh-sync:apply-remote:\(diff.headID)")
                case .preferLocal:
                    skippedCount += 1
                    reasonCodes.append(
                        "mesh-sync:keep-local:\(diff.headID)")
                case .sovereignReview:
                    skippedCount += 1
                    sovereignReviewCount += 1
                    reasonCodes.append(
                        "mesh-sync:sovereign-review:" +
                        "\(diff.headID)")
                }
            }
        }

        return BASMeshSyncFrameMergeReport(
            doctrineApplied: doctrine,
            appliedCount: appliedCount,
            skippedCount: skippedCount,
            conflictCount: conflictCount,
            sovereignReviewCount: sovereignReviewCount,
            reasonCodes: reasonCodes)
    }
}
