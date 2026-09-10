import Foundation

extension BASDerivedMemoryDraft {
    public var governanceDraftInput: BASMemoryGovernanceDraftInput {
        BASMemoryGovernanceDraftInput(
            id: id,
            typeID: typeID,
            topic: topic,
            headline: headline,
            value: value,
            confidence: confidence,
            priority: priority,
            source: BASMemorySource(identifier: sourceID) ?? .archive,
            lastConfirmedAt: lastConfirmedAt,
            decayPolicy: BASMemoryDecayPolicy(rawValue: decayPolicyID) ?? .medium,
            retrievalTags: retrievalTags,
            evidenceCount: evidenceCount,
            provenanceSummary: provenanceSummary,
            promotionPolicy: promotionPolicy,
            tierID: tierID
        )
    }

    public var reconciliationDraftInput: BASMemoryReconciliationDraftInput {
        BASMemoryReconciliationDraftInput(
            draft: governanceDraftInput,
            fingerprint: fingerprint
        )
    }

    public var fingerprint: String {
        [
            id,
            typeID,
            topic,
            headline,
            value,
            String(format: "%.3f", confidence),
            String(format: "%.3f", priority),
            sourceID,
            lastConfirmedAt.ISO8601Format(),
            decayPolicyID,
            retrievalTags.sorted().joined(separator: "|"),
            String(evidenceCount),
            tierID
        ]
        .joined(separator: "::")
    }
}
