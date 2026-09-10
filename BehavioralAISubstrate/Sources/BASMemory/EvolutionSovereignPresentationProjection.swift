import Foundation

public extension BASEvolutionLineageSummary {
    var sovereignVerdictLevelID: String? {
        sovereignVerdict?.verdictLevel.rawValue
    }

    var sovereignVerdictLatched: Bool {
        sovereignVerdict?.latched == true
    }

    var sovereignForcedModeID: String? {
        sovereignVerdict?.forcedMode?.rawValue
    }

    var sovereignVerdictReasonCodes: [String] {
        sovereignVerdict?.reasonCodes ?? []
    }

    var sovereignTokenScopeIDs: [String] {
        sovereignCommitTokens.map(\.scope.rawValue)
    }

    var sovereignWarrantScopeIDs: [String] {
        sovereignWarrants.map(\.scope.rawValue)
    }

    var sovereignWarrantPolicyIDs: [String] {
        orderedUnique(
            sovereignWarrants.compactMap { warrant in
                compactPolicyID(for: warrant.policyHash)
            }
        )
    }

    var sovereignWarrantTTLIDs: [String] {
        orderedUnique(
            sovereignWarrants.compactMap { warrant in
                compactTTLID(
                    issuedAt: warrant.issuedAt,
                    expiresAt: warrant.expiresAt
                )
            }
        )
    }

    var sovereignWarrantWitnessCount: Int {
        Set(sovereignWarrants.flatMap(\.witnessRefs)).count
    }

    var sovereignLockScopeID: String? {
        sovereignLock?.scope.rawValue
    }

    var sovereignQuarantineZoneIDs: [String] {
        quarantineRecords.map(\.zone.rawValue)
    }

    var sovereignAuditRuleIDs: [String] {
        sovereignAuditEntry?.ruleIDs ?? []
    }

    var sovereignAuditEntryID: String? {
        sovereignAuditEntry?.auditID
    }
}

private func orderedUnique(_ values: [String]) -> [String] {
    values.reduce(into: [String]()) { uniqueValues, value in
        guard !uniqueValues.contains(value) else { return }
        uniqueValues.append(value)
    }
}

private func compactPolicyID(for policyHash: String) -> String? {
    let trimmed = policyHash.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }
    guard trimmed.count > 16 else { return trimmed }
    return String(trimmed.prefix(16))
}

private func compactTTLID(issuedAt: Date?, expiresAt: Date?) -> String? {
    guard let issuedAt, let expiresAt else { return nil }
    let ttlSeconds = max(0, Int(expiresAt.timeIntervalSince(issuedAt).rounded()))
    guard ttlSeconds > 0 else { return "0s" }
    if ttlSeconds % 60 == 0 {
        return "\(ttlSeconds / 60)m"
    }
    return "\(ttlSeconds)s"
}
