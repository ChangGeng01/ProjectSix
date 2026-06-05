// Single source of truth for the risk-band cutoffs (a 0...1 risk / GSI score → level).
//
// Audit ch1040: the identical `..<0.35 / ..<0.60 / ..<0.82` ladder was copy-pasted at TWO
// sites in EBrainServiceContracts.swift — the neural-materialization `riskLevelResolver`
// closure and `riskLevel(for:)`. These are the exact cutoffs that decide whether a turn is
// classified low / medium / high / extreme, so editing one boundary silently desynced the
// other. Both now classify against THIS, so they can never drift. Byte-equal by construction:
// same cutoffs, same mapping.

import BASPolicy

public enum BASRiskBandThresholds {
    /// score < `lowCeiling` → `.low`
    public static let lowCeiling: Double = 0.35
    /// `lowCeiling` ≤ score < `mediumCeiling` → `.medium`
    public static let mediumCeiling: Double = 0.60
    /// `mediumCeiling` ≤ score < `highCeiling` → `.high`; score ≥ `highCeiling` → `.extreme`
    public static let highCeiling: Double = 0.82

    /// Classify a risk / GSI score into a band. The single classifier both call sites use.
    public static func band(for score: Double) -> BASBrainRiskLevel {
        switch score {
        case ..<lowCeiling:    return .low
        case ..<mediumCeiling: return .medium
        case ..<highCeiling:   return .high
        default:               return .extreme
        }
    }
}
