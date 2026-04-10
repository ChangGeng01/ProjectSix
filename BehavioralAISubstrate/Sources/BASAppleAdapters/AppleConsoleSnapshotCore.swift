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

        return "\(roleName) • \(boundaryModeID) • \(calibrationStatusID) • fingerprint \(verificationSnapshot)"
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
}
