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
