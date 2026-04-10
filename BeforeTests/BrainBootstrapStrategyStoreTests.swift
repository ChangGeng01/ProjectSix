import XCTest
import SwiftData
@testable import Before

final class BrainBootstrapStrategyStoreTests: XCTestCase {
    @MainActor
    func testSelectTemplatesUsesSubstrateOrderingAndFiltersByModeAndRisk() throws {
        let container = try makeTemplateContainer()
        let context = container.mainContext
        context.insert(
            InterventionTemplateRecord(
                id: "fallback_template",
                updatedAt: date("2026-04-10T10:00:00Z"),
                title: "Fallback",
                summary: "Fallback",
                body: ["Fallback"],
                mode: .quick,
                riskLevel: .medium,
                isPinned: false,
                successCount: 8
            )
        )
        context.insert(
            InterventionTemplateRecord(
                id: "tomorrow_box_interrupt",
                updatedAt: date("2026-04-10T09:00:00Z"),
                title: "Pinned",
                summary: "Pinned",
                body: ["Pinned"],
                mode: .quick,
                riskLevel: .medium,
                isPinned: true,
                successCount: 2
            )
        )
        context.insert(
            InterventionTemplateRecord(
                id: "wrong_mode",
                updatedAt: date("2026-04-10T11:00:00Z"),
                title: "Wrong",
                summary: "Wrong",
                body: ["Wrong"],
                mode: .mirror,
                riskLevel: .medium,
                isPinned: true,
                successCount: 99
            )
        )

        let ordered = InterventionTemplateStore.selectTemplates(
            in: context,
            mode: .quick,
            riskLevel: .medium,
            recommendedArmIDs: ["tomorrow_box_interrupt", "fallback_template"]
        )

        XCTAssertEqual(ordered.map(\.id), ["tomorrow_box_interrupt", "fallback_template"])
    }

    @MainActor
    func testSelectedFailurePatternsUsesSubstrateOrdering() throws {
        let container = try makeFailureContainer()
        let context = container.mainContext
        context.insert(
            FailurePatternRecord(
                id: "night_fast_path_failure",
                updatedAt: date("2026-04-10T09:00:00Z"),
                mode: .quick,
                title: "Night",
                detail: "Night",
                cadenceTag: "night",
                suppressionWeight: 0.9,
                evidenceCount: 2
            )
        )
        context.insert(
            FailurePatternRecord(
                id: "proceed_without_pause_failure",
                updatedAt: date("2026-04-10T08:00:00Z"),
                mode: .quick,
                title: "Proceed",
                detail: "Proceed",
                cadenceTag: "proceed",
                suppressionWeight: 0.9,
                evidenceCount: 4
            )
        )
        context.insert(
            FailurePatternRecord(
                id: "mirror_only_failure",
                updatedAt: date("2026-04-10T12:00:00Z"),
                mode: .mirror,
                title: "Mirror",
                detail: "Mirror",
                cadenceTag: "mirror",
                suppressionWeight: 1.0,
                evidenceCount: 10
            )
        )

        let ordered = FailurePatternStore.selectedFailurePatterns(
            in: context,
            mode: .quick
        )

        XCTAssertEqual(ordered.map(\.id), ["proceed_without_pause_failure", "night_fast_path_failure"])
    }

    @MainActor
    private func makeTemplateContainer() throws -> ModelContainer {
        try ModelContainer(
            for: InterventionTemplateRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    @MainActor
    private func makeFailureContainer() throws -> ModelContainer {
        try ModelContainer(
            for: CheckEvent.self,
            FailurePatternRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private func date(_ value: String) -> Date {
        ISO8601DateFormatter().date(from: value) ?? .distantPast
    }
}
