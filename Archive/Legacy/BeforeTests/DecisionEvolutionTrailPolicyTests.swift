import XCTest
import BASHostKit
@testable import Before

final class DecisionEvolutionTrailPolicyTests: XCTestCase {
    func testEvolutionTrailCheckpointsUseSharedInclusionRule() {
        let empty = DecisionEvolutionCheckpoint(
            id: "empty",
            createdAt: Date(timeIntervalSince1970: 1),
            fingerprint: "empty",
            previousCheckpointID: nil,
            mode: .quick,
            source: .explicitRefresh,
            identityRole: .pauseCompanion,
            boundaryMode: .localOnlyProtective,
            calibrationStatus: .stable,
            diffSummary: [],
            approvalState: .automatic,
            rollbackReady: false,
            brainStateSnapshot: nil,
            lineageSummary: nil
        )
        let diffOnly = DecisionEvolutionCheckpoint(
            id: "diff",
            createdAt: Date(timeIntervalSince1970: 2),
            fingerprint: "diff",
            previousCheckpointID: nil,
            mode: .balance,
            source: .explicitRefresh,
            identityRole: .pauseCompanion,
            boundaryMode: .localOnlyProtective,
            calibrationStatus: .stable,
            diffSummary: ["added candidate scoring"],
            approvalState: .automatic,
            rollbackReady: false,
            brainStateSnapshot: nil,
            lineageSummary: nil
        )
        let lineageOnly = DecisionEvolutionCheckpoint(
            id: "lineage",
            createdAt: Date(timeIntervalSince1970: 3),
            fingerprint: "lineage",
            previousCheckpointID: nil,
            mode: .mirror,
            source: .explicitRefresh,
            identityRole: .pauseCompanion,
            boundaryMode: .localOnlyProtective,
            calibrationStatus: .watch,
            diffSummary: [],
            approvalState: .reviewSuggested,
            rollbackReady: true,
            brainStateSnapshot: nil,
            lineageSummary: BASEvolutionLineageSummary(
                recordedAt: Date(timeIntervalSince1970: 3),
                sessionID: "session-lineage",
                taskType: "decision",
                riskLevel: "watch",
                permitMode: "delay",
                hostGatePercent: 65,
                thoughtFoldChecksum: "fold-lineage",
                updateTicketSummaries: [],
                guardrailFindings: [],
                recommendedKillSwitches: []
            )
        )

        XCTAssertFalse(empty.isIncludedInEvolutionTrail)
        XCTAssertTrue(diffOnly.isIncludedInEvolutionTrail)
        XCTAssertTrue(lineageOnly.isIncludedInEvolutionTrail)
        XCTAssertEqual(
            [empty, diffOnly, lineageOnly].evolutionTrailCheckpoints().map(\.id),
            ["diff", "lineage"]
        )
    }
}
