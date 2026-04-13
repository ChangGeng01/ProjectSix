import Foundation
import SwiftData
import BASHostKit

@Model
final class BrainStateUpdate {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var sourceRaw: String
    var modeRaw: String
    var dominantGoal: String?
    var dominantReactionWeightRaw: String
    var fingerprint: String
    var activeConstraintBlob: String
    var activeTemplateIDsBlob: String
    var failureGuardIDsBlob: String

    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        source: BrainStateUpdateSource,
        mode: DecisionMode,
        dominantGoal: String?,
        dominantReactionWeight: DecisionReactionWeightKey,
        fingerprint: String,
        activeConstraints: [String],
        activeTemplateIDs: [String],
        failureGuardIDs: [String]
    ) {
        self.id = id
        self.createdAt = createdAt
        self.sourceRaw = source.rawValue
        self.modeRaw = mode.rawValue
        self.dominantGoal = dominantGoal
        self.dominantReactionWeightRaw = dominantReactionWeight.rawValue
        self.fingerprint = fingerprint
        self.activeConstraintBlob = Self.encode(activeConstraints)
        self.activeTemplateIDsBlob = Self.encode(activeTemplateIDs)
        self.failureGuardIDsBlob = Self.encode(failureGuardIDs)
    }

    convenience init(storedFields: BASCurrentBrainUpdateStoredFields) {
        self.init(
            id: storedFields.id,
            createdAt: storedFields.createdAt,
            source: BrainStateUpdateSource(rawValue: storedFields.source) ?? .explicitRefresh,
            mode: DecisionMode(rawValue: storedFields.mode) ?? .quick,
            dominantGoal: storedFields.dominantGoal,
            dominantReactionWeight: DecisionReactionWeightKey(rawValue: storedFields.dominantReactionWeight) ?? .briefLanguage,
            fingerprint: storedFields.fingerprint,
            activeConstraints: storedFields.activeConstraints,
            activeTemplateIDs: storedFields.activeTemplateIDs,
            failureGuardIDs: storedFields.failureGuardIDs
        )
    }

    var source: BrainStateUpdateSource {
        BrainStateUpdateSource(rawValue: sourceRaw) ?? .explicitRefresh
    }

    var mode: DecisionMode {
        DecisionMode(rawValue: modeRaw) ?? .quick
    }

    var dominantReactionWeight: DecisionReactionWeightKey {
        DecisionReactionWeightKey(rawValue: dominantReactionWeightRaw) ?? .briefLanguage
    }

    var activeConstraints: [String] {
        Self.decode(activeConstraintBlob)
    }

    var activeTemplateIDs: [String] {
        Self.decode(activeTemplateIDsBlob)
    }

    var failureGuardIDs: [String] {
        Self.decode(failureGuardIDsBlob)
    }

    var storedFields: BASCurrentBrainUpdateStoredFields {
        BASCurrentBrainUpdateStoredFields(
            id: id,
            createdAt: createdAt,
            source: sourceRaw,
            mode: modeRaw,
            dominantGoal: dominantGoal,
            dominantReactionWeight: dominantReactionWeightRaw,
            fingerprint: fingerprint,
            activeConstraints: activeConstraints,
            activeTemplateIDs: activeTemplateIDs,
            failureGuardIDs: failureGuardIDs
        )
    }

    static func encode(_ values: [String]) -> String {
        guard let data = try? JSONEncoder().encode(values),
              let string = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return string
    }

    static func encodeCodable<Value: Encodable>(_ value: Value?) -> String? {
        guard let value,
              let data = try? JSONEncoder().encode(value),
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        return string
    }

    static func decode(_ blob: String) -> [String] {
        guard let data = blob.data(using: .utf8),
              let values = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return values
    }

    static func decodeCodable<Value: Decodable>(_ blob: String?, as type: Value.Type) -> Value? {
        guard let blob,
              let data = blob.data(using: .utf8),
              let value = try? JSONDecoder().decode(Value.self, from: data) else {
            return nil
        }
        return value
    }
}

@Model
final class InterventionTrigger {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var riskLevelRaw: String
    var title: String
    var detail: String
    var reason: String
    var suggestedModeRaw: String?
    var wasDelivered: Bool
    var wasDismissed: Bool

    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        riskLevel: InterventionRiskLevel,
        title: String,
        detail: String,
        reason: String,
        suggestedMode: DecisionMode? = nil,
        wasDelivered: Bool,
        wasDismissed: Bool = false
    ) {
        self.id = id
        self.createdAt = createdAt
        self.riskLevelRaw = riskLevel.rawValue
        self.title = title
        self.detail = detail
        self.reason = reason
        self.suggestedModeRaw = suggestedMode?.rawValue
        self.wasDelivered = wasDelivered
        self.wasDismissed = wasDismissed
    }

    var riskLevel: InterventionRiskLevel {
        InterventionRiskLevel(rawValue: riskLevelRaw) ?? .low
    }

    var suggestedMode: DecisionMode? {
        suggestedModeRaw.flatMap(DecisionMode.init(rawValue:))
    }
}

@Model
final class InterventionTemplateRecord {
    @Attribute(.unique) var id: String
    var createdAt: Date
    var updatedAt: Date
    var title: String
    var summary: String
    var bodyBlob: String
    var modeRaw: String
    var riskLevelRaw: String
    var isPinned: Bool
    var successCount: Int

    init(
        id: String,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        title: String,
        summary: String,
        body: [String],
        mode: DecisionMode,
        riskLevel: InterventionRiskLevel,
        isPinned: Bool = false,
        successCount: Int = 0
    ) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.title = title
        self.summary = summary
        self.bodyBlob = BrainStateUpdate.encode(body)
        self.modeRaw = mode.rawValue
        self.riskLevelRaw = riskLevel.rawValue
        self.isPinned = isPinned
        self.successCount = successCount
    }

    var body: [String] {
        BrainStateUpdate.decode(bodyBlob)
    }

    var mode: DecisionMode {
        DecisionMode(rawValue: modeRaw) ?? .quick
    }

    var riskLevel: InterventionRiskLevel {
        InterventionRiskLevel(rawValue: riskLevelRaw) ?? .low
    }
}

@Model
final class FailurePatternRecord {
    @Attribute(.unique) var id: String
    var createdAt: Date
    var updatedAt: Date
    var modeRaw: String
    var title: String
    var detail: String
    var cadenceTag: String
    var suppressionWeight: Double
    var evidenceCount: Int

    init(
        id: String,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        mode: DecisionMode,
        title: String,
        detail: String,
        cadenceTag: String,
        suppressionWeight: Double,
        evidenceCount: Int
    ) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.modeRaw = mode.rawValue
        self.title = title
        self.detail = detail
        self.cadenceTag = cadenceTag
        self.suppressionWeight = suppressionWeight
        self.evidenceCount = evidenceCount
    }

    var mode: DecisionMode {
        DecisionMode(rawValue: modeRaw) ?? .quick
    }
}
