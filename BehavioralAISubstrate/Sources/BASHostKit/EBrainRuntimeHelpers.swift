import Foundation
import BASMemory
import BASOrchestration
import BASPolicy
import BASRuntimeCore

// MARK: - M71 split — shared internal helpers for EBrainRuntimeCoordinator family.
// These were previously file-scope `private` in EBrainRuntimeCoordinator.swift; on the
// M71 cohesion split they became `internal` so sibling extension files (all in
// BASHostKit) can share a single definition.  They are NOT part of the public API
// surface — they stay internal to the BAS module.

struct EvolutionSovereignBridgeProjection {
    let actuationKinds: [BASSovereignActuationKind]
    let invalidatedResumeFrameIDs: [String]
    let invalidatedCacheRefs: [String]
    let invalidatedFoldRefs: [String]
    let quarantinedFoldRefs: [String]
    let resultingBreathMode: String?
    let preservedReadOnlyRecovery: Bool?
    let summary: String?
}

extension BASActionPermitMode {
    /// True for permit modes that WITHHOLD / guard emission (delay, draft-only, local-only, block,
    /// replace, escalate) vs the freely-emitting answer/mirror/compare. Public so hosts (e.g. the
    /// journal's governance-verdict fold) classify abstention off the substrate's own definition
    /// rather than a hand-maintained subset that could drift.
    public var isProtective: Bool {
        switch self {
        case .mirror, .compare:
            return false
        case .answer:
            return false
        case .delay, .draftOnly, .localOnly, .block, .replace, .escalate:
            return true
        }
    }
}

extension String {
    var trimmedNonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

extension Sequence where Element == String {
    func runtimeOrderedUniqueStrings() -> [String] {
        var seen = Set<String>()
        return filter { seen.insert($0).inserted }
    }
}

func evolutionJoined(_ parts: [String?]) -> String? {
    let segments = parts.compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
    guard segments.isEmpty == false else {
        return nil
    }
    return segments.joined(separator: " • ")
}
