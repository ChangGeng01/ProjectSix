import Foundation
import BASAdmin
import BASObservability

public struct BASAppleConsoleSnapshotSourceInput: Codable, Equatable, Sendable {
    public var generatedAt: Date
    public var flightDeckCompilation: BASAppleFlightDeckCompilation
    public var activeProviderTitle: String
    public var runtimeGearID: String
    public var totalRequests: Int
    public var totalProviderAttempts: Int
    public var layerStackLines: [String]?
    public var roleName: String?
    public var boundaryModeID: String?
    public var calibrationStatusID: String?
    public var verificationSnapshot: String?
    public var capabilityCoverage: BASCapabilityCoverageReport?
    public var inspectionBundle: BASInspectionBundle?

    public init(
        generatedAt: Date = .now,
        flightDeckCompilation: BASAppleFlightDeckCompilation,
        activeProviderTitle: String,
        runtimeGearID: String,
        totalRequests: Int,
        totalProviderAttempts: Int,
        layerStackLines: [String]? = nil,
        roleName: String? = nil,
        boundaryModeID: String? = nil,
        calibrationStatusID: String? = nil,
        verificationSnapshot: String? = nil,
        capabilityCoverage: BASCapabilityCoverageReport? = nil,
        inspectionBundle: BASInspectionBundle? = nil
    ) {
        self.generatedAt = generatedAt
        self.flightDeckCompilation = flightDeckCompilation
        self.activeProviderTitle = activeProviderTitle
        self.runtimeGearID = runtimeGearID
        self.totalRequests = totalRequests
        self.totalProviderAttempts = totalProviderAttempts
        self.layerStackLines = layerStackLines
        self.roleName = roleName
        self.boundaryModeID = boundaryModeID
        self.calibrationStatusID = calibrationStatusID
        self.verificationSnapshot = verificationSnapshot
        self.capabilityCoverage = capabilityCoverage
        self.inspectionBundle = inspectionBundle
    }
}

public enum BASAppleConsoleSnapshotBuilder {
    public static func build(
        from input: BASAppleConsoleSnapshotSourceInput
    ) -> BASConsoleSnapshot {
        BASConsoleSnapshotBuilder.build(
            from: BASFlightDeckMetrics(
                generatedAt: input.generatedAt,
                layerInputs: input.flightDeckCompilation.layerReports.map { report in
                    BASLayerAssessmentInput(
                        layer: layerKind(from: report.layerID),
                        score: Double(report.score),
                        summary: report.headline,
                        blockers: report.blockers
                    )
                },
                runtimeSummary: runtimeSummary(from: input),
                layerStackLines: input.layerStackLines,
                brainSummary: brainSummary(from: input),
                isPureLocal: input.flightDeckCompilation.isPureLocalClosedLoop,
                capabilityCoverage: input.capabilityCoverage,
                inspectionBundle: input.inspectionBundle
            )
        )
    }

    private static func runtimeSummary(
        from input: BASAppleConsoleSnapshotSourceInput
    ) -> String {
        "Route \(input.activeProviderTitle) • gear \(input.runtimeGearID) • requests \(input.totalRequests) • attempts \(input.totalProviderAttempts)"
    }

    private static func brainSummary(
        from input: BASAppleConsoleSnapshotSourceInput
    ) -> String? {
        guard
            let roleName = input.roleName,
            let boundaryModeID = input.boundaryModeID,
            let calibrationStatusID = input.calibrationStatusID,
            let verificationSnapshot = input.verificationSnapshot
        else {
            return nil
        }

        let parsed = parsedVerificationSnapshot(verificationSnapshot)
        let constitutionSummary = parsed.constitutionVersion.map { "constitution \($0)" }
        let phaseSummary = parsed.constitutionPhase.map { "phase \($0)" }

        return [
            roleName,
            boundaryModeID,
            calibrationStatusID,
            constitutionSummary,
            phaseSummary,
            "fingerprint \(parsed.baseFingerprint)"
        ]
        .compactMap { $0 }
        .joined(separator: " • ")
    }

    private static func layerKind(from layerID: String) -> BASLayerKind {
        switch layerID {
        case "runtime":
            .runtime
        case "data":
            .data
        case "memory":
            .memory
        case "safety":
            .security
        case "orchestration":
            .orchestration
        case "observability":
            .observability
        case "evaluation":
            .evaluation
        case "delivery":
            .delivery
        default:
            .observability
        }
    }

    private static func parsedVerificationSnapshot(
        _ raw: String
    ) -> (baseFingerprint: String, constitutionVersion: String?, constitutionPhase: String?) {
        let parts = raw.split(separator: "|").map(String.init)
        let baseFingerprint = parts.first ?? raw
        let constitutionVersion = parts.first { $0.hasPrefix("constitution:") }
            .map { String($0.dropFirst("constitution:".count)) }
        let constitutionPhase = parts.first { $0.hasPrefix("phase:") }
            .map { String($0.dropFirst("phase:".count)) }
        return (baseFingerprint, constitutionVersion, constitutionPhase)
    }
}
