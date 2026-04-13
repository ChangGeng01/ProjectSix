import Foundation
import BASRuntimeCore

public enum BASBrainRiskLevel: String, Codable, CaseIterable, Sendable, Comparable {
    case low
    case medium
    case high
    case extreme

    public static func < (lhs: BASBrainRiskLevel, rhs: BASBrainRiskLevel) -> Bool {
        lhs.rank < rhs.rank
    }

    private var rank: Int {
        switch self {
        case .low:
            0
        case .medium:
            1
        case .high:
            2
        case .extreme:
            3
        }
    }
}

public enum BASActionPermitMode: String, Codable, CaseIterable, Sendable {
    case answer
    case compare
    case delay
    case block
    case replace
}

public struct BASActionPermit: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var mode: BASActionPermitMode
    public var reasonCodes: [String]
    public var requireSecondCheck: Bool
    public var outputLengthCap: Int
    public var tonePolicy: String
    public var templatePolicy: String

    public init(
        schemaVersion: String = BASActionPermit.currentSchemaVersion,
        mode: BASActionPermitMode,
        reasonCodes: [String] = [],
        requireSecondCheck: Bool = false,
        outputLengthCap: Int = 240,
        tonePolicy: String = "grounded_clear",
        templatePolicy: String = "default"
    ) {
        self.schemaVersion = schemaVersion
        self.mode = mode
        self.reasonCodes = reasonCodes
        self.requireSecondCheck = requireSecondCheck
        self.outputLengthCap = max(0, outputLengthCap)
        self.tonePolicy = tonePolicy
        self.templatePolicy = templatePolicy
    }
}

public extension BASActionPermit {
    static func protectiveBlock(reasonCodes: [String]) -> BASActionPermit {
        BASActionPermit(
            mode: .block,
            reasonCodes: reasonCodes,
            requireSecondCheck: true,
            outputLengthCap: 120,
            tonePolicy: "clear_firm",
            templatePolicy: "protective_alternative"
        )
    }
}

public struct BASRiskCard: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var totalRisk: Double
    public var riskLevel: BASBrainRiskLevel
    public var factors: [String]
    public var uncertainty: Double
    public var irreversibility: Double
    public var manipulationStrength: Double
    public var gsiScore: Double
    public var recommendedMode: BASActionPermitMode

    public init(
        schemaVersion: String = BASRiskCard.currentSchemaVersion,
        totalRisk: Double,
        riskLevel: BASBrainRiskLevel,
        factors: [String] = [],
        uncertainty: Double,
        irreversibility: Double,
        manipulationStrength: Double,
        gsiScore: Double,
        recommendedMode: BASActionPermitMode
    ) {
        self.schemaVersion = schemaVersion
        self.totalRisk = min(max(totalRisk, 0), 1)
        self.riskLevel = riskLevel
        self.factors = factors
        self.uncertainty = min(max(uncertainty, 0), 1)
        self.irreversibility = min(max(irreversibility, 0), 1)
        self.manipulationStrength = min(max(manipulationStrength, 0), 1)
        self.gsiScore = min(max(gsiScore, 0), 1)
        self.recommendedMode = recommendedMode
    }
}
