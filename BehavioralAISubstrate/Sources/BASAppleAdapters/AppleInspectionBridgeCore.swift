import Foundation
import BASAdmin
import BASMemory
import BASObservability
import BASPolicy
import BASRuntimeCore

public struct BASAppleRuntimeContextSourceInput: Codable, Equatable, Sendable {
    public var primaryTraceKind: String?
    public var runtimeGear: BASRuntimeGear
    public var environmentClass: BASEnvironmentClass
    public var deviceClass: BASDevicePerformanceClass
    public var riskLevel: BASRiskLevel
    public var budget: BASAdaptiveRuntimeBudget

    public init(
        primaryTraceKind: String?,
        runtimeGear: BASRuntimeGear,
        environmentClass: BASEnvironmentClass,
        deviceClass: BASDevicePerformanceClass,
        riskLevel: BASRiskLevel,
        budget: BASAdaptiveRuntimeBudget
    ) {
        self.primaryTraceKind = primaryTraceKind
        self.runtimeGear = runtimeGear
        self.environmentClass = environmentClass
        self.deviceClass = deviceClass
        self.riskLevel = riskLevel
        self.budget = budget
    }
}

public struct BASAppleRawRuntimeContextSourceInput: Codable, Equatable, Sendable {
    public var primaryTraceKindID: String?
    public var runtimeGearID: String
    public var environmentClassID: String
    public var deviceClassID: String
    public var riskLevelID: String
    public var budget: BASAdaptiveRuntimeBudget

    public init(
        primaryTraceKindID: String?,
        runtimeGearID: String,
        environmentClassID: String,
        deviceClassID: String,
        riskLevelID: String,
        budget: BASAdaptiveRuntimeBudget
    ) {
        self.primaryTraceKindID = primaryTraceKindID
        self.runtimeGearID = runtimeGearID
        self.environmentClassID = environmentClassID
        self.deviceClassID = deviceClassID
        self.riskLevelID = riskLevelID
        self.budget = budget
    }
}

public struct BASAppleRoleProfileSourceInput: Codable, Equatable, Sendable {
    public var name: String
    public var postureID: String
    public var initiativeID: String
    public var confidenceCeiling: Double
    public var roleBoundaryPreset: String

    public init(
        name: String,
        postureID: String,
        initiativeID: String,
        confidenceCeiling: Double,
        roleBoundaryPreset: String
    ) {
        self.name = name
        self.postureID = postureID
        self.initiativeID = initiativeID
        self.confidenceCeiling = confidenceCeiling
        self.roleBoundaryPreset = roleBoundaryPreset
    }
}

public struct BASAppleBrainSnapshotSourceInput: Codable, Equatable, Sendable {
    public var mode: String
    public var dominantGoals: [String]
    public var activeConstraints: [String]
    public var warmth: Double
    public var directness: Double
    public var brevity: Double
    public var actionBias: Double
    public var activeTemplateIDs: [String]
    public var recentFailurePatternIDs: [String]
    public var retrievalTags: [String]
    public var verificationSnapshot: String
    public var constitutionVersion: String?
    public var constitutionPhase: String?
    public var constitutionValueAxisCount: Int?

    public init(
        mode: String,
        dominantGoals: [String],
        activeConstraints: [String],
        warmth: Double,
        directness: Double,
        brevity: Double,
        actionBias: Double,
        activeTemplateIDs: [String],
        recentFailurePatternIDs: [String],
        retrievalTags: [String],
        verificationSnapshot: String,
        constitutionVersion: String? = nil,
        constitutionPhase: String? = nil,
        constitutionValueAxisCount: Int? = nil
    ) {
        self.mode = mode
        self.dominantGoals = dominantGoals
        self.activeConstraints = activeConstraints
        self.warmth = warmth
        self.directness = directness
        self.brevity = brevity
        self.actionBias = actionBias
        self.activeTemplateIDs = activeTemplateIDs
        self.recentFailurePatternIDs = recentFailurePatternIDs
        self.retrievalTags = retrievalTags
        self.verificationSnapshot = verificationSnapshot
        self.constitutionVersion = constitutionVersion
        self.constitutionPhase = constitutionPhase
        self.constitutionValueAxisCount = constitutionValueAxisCount
    }
}

public struct BASAppleConsoleBridgeSourceInput: Codable, Equatable, Sendable {
    public var generatedAt: Date
    public var flightDeckCompilation: BASAppleFlightDeckCompilation
    public var activeProviderTitle: String
    public var totalRequests: Int
    public var totalProviderAttempts: Int
    public var layerStackLines: [String]?
    public var runtimeContext: BASRuntimeContext
    public var roleProfile: BASRoleProfile?
    public var boundaryModeID: String?
    public var calibrationStatusID: String?
    public var brainState: BASCurrentBrainState?
    public var capabilityCoverage: BASCapabilityCoverageReport?
    public var inspectionBundle: BASInspectionBundle?

    public init(
        generatedAt: Date = .now,
        flightDeckCompilation: BASAppleFlightDeckCompilation,
        activeProviderTitle: String,
        totalRequests: Int,
        totalProviderAttempts: Int,
        layerStackLines: [String]? = nil,
        runtimeContext: BASRuntimeContext,
        roleProfile: BASRoleProfile?,
        boundaryModeID: String? = nil,
        calibrationStatusID: String? = nil,
        brainState: BASCurrentBrainState? = nil,
        capabilityCoverage: BASCapabilityCoverageReport? = nil,
        inspectionBundle: BASInspectionBundle? = nil
    ) {
        self.generatedAt = generatedAt
        self.flightDeckCompilation = flightDeckCompilation
        self.activeProviderTitle = activeProviderTitle
        self.totalRequests = totalRequests
        self.totalProviderAttempts = totalProviderAttempts
        self.layerStackLines = layerStackLines
        self.runtimeContext = runtimeContext
        self.roleProfile = roleProfile
        self.boundaryModeID = boundaryModeID
        self.calibrationStatusID = calibrationStatusID
        self.brainState = brainState
        self.capabilityCoverage = capabilityCoverage
        self.inspectionBundle = inspectionBundle
    }
}

public enum BASAppleInspectionBridgeBuilder {
    public static func runtimeContext(
        from rawInput: BASAppleRawRuntimeContextSourceInput
    ) -> BASRuntimeContext {
        runtimeContext(
            from: BASAppleRuntimeContextSourceInput(
                primaryTraceKind: rawInput.primaryTraceKindID,
                runtimeGear: BASRuntimeGear(rawValue: rawInput.runtimeGearID) ?? .balanced,
                environmentClass: BASEnvironmentClass(rawValue: rawInput.environmentClassID) ?? .normal,
                deviceClass: BASDevicePerformanceClass(rawValue: rawInput.deviceClassID) ?? .balancedPhone,
                riskLevel: BASRiskLevel(rawValue: rawInput.riskLevelID) ?? .low,
                budget: rawInput.budget
            )
        )
    }

    public static func runtimeContext(
        from input: BASAppleRuntimeContextSourceInput
    ) -> BASRuntimeContext {
        BASRuntimeContext(
            taskKind: taskKind(from: input.primaryTraceKind),
            gear: input.runtimeGear,
            deviceProfile: BASDeviceProfile(
                modelName: input.deviceClass.rawValue,
                memoryMB: memoryMB(for: input.deviceClass),
                batteryLevel: 1.0,
                lowPowerMode: input.environmentClass == .lowPower,
                thermalState: input.environmentClass.rawValue
            ),
            privacyMode: .localOnly,
            riskLevel: input.riskLevel,
            networkAvailable: false,
            budget: BASExecutionBudget(
                contextTokens: input.budget.contextBudget,
                outputTokens: input.budget.outputCharacterBudget,
                retrievalItems: input.budget.retrievalItemBudget,
                toolCalls: input.budget.toolCallBudget,
                timeBudgetMs: input.budget.timeBudgetMs
            )
        )
    }

    public static func roleProfile(
        name: String,
        postureID: String,
        initiativeID: String,
        confidenceCeiling: Double,
        roleBoundaryPreset: String
    ) -> BASRoleProfile? {
        roleProfile(
            from: BASAppleRoleProfileSourceInput(
                name: name,
                postureID: postureID,
                initiativeID: initiativeID,
                confidenceCeiling: confidenceCeiling,
                roleBoundaryPreset: roleBoundaryPreset
            )
        )
    }

    public static func roleProfile(
        from input: BASAppleRoleProfileSourceInput?
    ) -> BASRoleProfile? {
        guard let input else { return nil }
        return BASRoleProfile(
            name: input.name,
            posture: posture(from: input.postureID),
            initiative: initiative(from: input.initiativeID),
            confidenceCeiling: input.confidenceCeiling,
            roleBoundaryPreset: input.roleBoundaryPreset
        )
    }

    public static func brainSnapshot(
        modeID: String,
        dominantGoals: [String],
        activeConstraints: [String],
        warmth: Double,
        directness: Double,
        brevity: Double,
        actionBias: Double,
        activeTemplateIDs: [String],
        recentFailurePatternIDs: [String],
        retrievalTags: [String],
        verificationSnapshot: String
    ) -> BASCurrentBrainState? {
        brainSnapshot(
            from: BASAppleBrainSnapshotSourceInput(
                mode: modeID,
                dominantGoals: dominantGoals,
                activeConstraints: activeConstraints,
                warmth: warmth,
                directness: directness,
                brevity: brevity,
                actionBias: actionBias,
                activeTemplateIDs: activeTemplateIDs,
                recentFailurePatternIDs: recentFailurePatternIDs,
                retrievalTags: retrievalTags,
                verificationSnapshot: verificationSnapshot
            )
        )
    }

    public static func brainSnapshot(
        from input: BASAppleBrainSnapshotSourceInput?
    ) -> BASCurrentBrainState? {
        guard let input else { return nil }
        let constitutionRetrievalTags = constitutionMarkers(
            version: input.constitutionVersion,
            phase: input.constitutionPhase,
            valueAxisCount: input.constitutionValueAxisCount
        )
        let verificationSnapshot = constitutionVerificationSnapshot(
            base: input.verificationSnapshot,
            version: input.constitutionVersion,
            phase: input.constitutionPhase
        )
        return BASCurrentBrainState(
            mode: input.mode,
            dominantGoals: input.dominantGoals,
            activeConstraints: input.activeConstraints,
            reactionWeights: BASReactionWeights(
                warmth: input.warmth,
                directness: input.directness,
                brevity: input.brevity,
                actionBias: input.actionBias
            ),
            activeTemplateIDs: input.activeTemplateIDs.compactMap(UUID.init(uuidString:)),
            recentFailurePatternIDs: input.recentFailurePatternIDs.compactMap(UUID.init(uuidString:)),
            retrievalTags: (input.retrievalTags + constitutionRetrievalTags).uniqued(),
            verificationSnapshot: verificationSnapshot
        )
    }

    public static func consoleSnapshot(
        from input: BASAppleConsoleBridgeSourceInput
    ) -> BASConsoleSnapshot {
        BASAppleConsoleSnapshotBuilder.build(
            from: BASAppleConsoleSnapshotSourceInput(
                generatedAt: input.generatedAt,
                flightDeckCompilation: input.flightDeckCompilation,
                activeProviderTitle: input.activeProviderTitle,
                runtimeGearID: input.runtimeContext.gear.rawValue,
                totalRequests: input.totalRequests,
                totalProviderAttempts: input.totalProviderAttempts,
                layerStackLines: input.layerStackLines,
                roleName: input.roleProfile?.name,
                boundaryModeID: input.boundaryModeID,
                calibrationStatusID: input.calibrationStatusID,
                verificationSnapshot: input.brainState?.verificationSnapshot,
                capabilityCoverage: input.capabilityCoverage,
                inspectionBundle: input.inspectionBundle
            )
        )
    }

    private static func taskKind(from primaryTraceKind: String?) -> BASTaskKind {
        switch primaryTraceKind.flatMap(BASAdaptiveTraceKind.init(identifier:)) {
        case .comparative?:
            .plan
        case .reflective?:
            .retrieve
        case .primary?, .selection?, nil:
            .chat
        }
    }

    private static func memoryMB(for deviceClass: BASDevicePerformanceClass) -> Int {
        switch deviceClass {
        case .simulator:
            8192
        case .memoryConstrainedPhone:
            4096
        case .balancedPhone:
            6144
        case .fullPhone:
            8192
        }
    }

    private static func posture(from postureID: String) -> BASRolePosture {
        switch postureID {
        case "reflective":
            .observe
        case "coaching":
            .coach
        case "protective":
            .guardian
        default:
            .companion
        }
    }

    private static func initiative(from initiativeID: String) -> BASRoleInitiative {
        switch initiativeID {
        case "passive":
            .passive
        case "guided":
            .balanced
        case "assertive":
            .assertive
        default:
            .balanced
        }
    }

    private static func constitutionMarkers(
        version: String?,
        phase: String?,
        valueAxisCount: Int?
    ) -> [String] {
        var markers: [String] = []
        if let version, !version.isEmpty {
            markers.append("constitution:\(version)")
        }
        if let phase, !phase.isEmpty {
            markers.append("constitution_phase:\(phase)")
        }
        if let valueAxisCount {
            markers.append("constitution_value_axes:\(valueAxisCount)")
        }
        return markers
    }

    private static func constitutionVerificationSnapshot(
        base: String,
        version: String?,
        phase: String?
    ) -> String {
        (
            [base]
            + constitutionMarkers(version: version, phase: phase, valueAxisCount: nil).map { marker in
                switch marker {
                case let value where value.hasPrefix("constitution:"):
                    return value
                case let value where value.hasPrefix("constitution_phase:"):
                    return "phase:\(String(value.dropFirst("constitution_phase:".count)))"
                default:
                    return marker
                }
            }
        )
        .uniqued()
        .joined(separator: "|")
    }
}

private extension Sequence where Element == String {
    func uniqued() -> [String] {
        var seen = Set<String>()
        return filter { seen.insert($0).inserted }
    }
}
