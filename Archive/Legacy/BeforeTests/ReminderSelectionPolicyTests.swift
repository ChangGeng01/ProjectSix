import XCTest
@testable import Before

final class ReminderSelectionPolicyTests: XCTestCase {
    func testUserWrittenRemindersOutrankTemplates() {
        let templateReminder = SelfReminder(
            content: "Template",
            scenario: .buy,
            source: .template,
            createdAt: .distantPast,
            lastUsedAt: .now,
            useCount: 99
        )
        let userReminder = SelfReminder(
            content: "User",
            scenario: .buy,
            source: .userWritten,
            createdAt: .now,
            lastUsedAt: .distantPast,
            useCount: 0
        )

        let ranked = ReminderSelectionPolicy.ranked(reminders: [templateReminder, userReminder])

        XCTAssertEqual(ranked.first?.id, userReminder.id)
    }

    func testTrimDropsLowestPriorityRemindersFirst() {
        let important = SelfReminder(content: "Important", scenario: .buy, source: .userWritten)
        let reminders = [important] + (0...10).map {
            SelfReminder(
                content: "Template \($0)",
                scenario: .other,
                source: .template,
                createdAt: Date(timeIntervalSince1970: TimeInterval($0))
            )
        }

        let trimmed = ReminderSelectionPolicy.remindersToTrim(from: reminders)

        XCTAssertEqual(trimmed.count, 2)
        XCTAssertFalse(trimmed.contains(where: { $0.id == important.id }))
    }

    func testSelectionAssessmentStaysControlOnlyWhenPromptHasNoKnowledgeSignal() {
        let assessment = ReminderSelectionPolicy.assessSelectionNeed(
            candidates: [
                ReminderSelectionCandidate(id: UUID(), content: "This is stress shopping again."),
                ReminderSelectionCandidate(id: UUID(), content: "You already knew this was a real replacement.", rank: 1)
            ],
            scenario: .buy,
            prompt: "",
            mode: .quick
        )

        XCTAssertEqual(assessment.need, .control)
        XCTAssertEqual(assessment.promptTokenCount, 0)
    }

    func testSelectionAssessmentDoesNotUseScenarioAndModeAsKnowledgeSignal() {
        let assessment = ReminderSelectionPolicy.assessSelectionNeed(
            candidates: [
                ReminderSelectionCandidate(id: UUID(), content: "Buy later when the rush is gone."),
                ReminderSelectionCandidate(id: UUID(), content: "Wait until tomorrow morning.", rank: 1)
            ],
            scenario: .buy,
            prompt: "",
            mode: .quick
        )

        XCTAssertEqual(assessment.need, .control)
        XCTAssertEqual(assessment.promptTokenCount, 0)
    }

    func testSelectionAssessmentEscalatesToKnowledgeWhenPromptCreatesRealCandidateConflict() {
        let assessment = ReminderSelectionPolicy.assessSelectionNeed(
            candidates: [
                ReminderSelectionCandidate(id: UUID(), content: "Stress shopping."),
                ReminderSelectionCandidate(id: UUID(), content: "Real replacement.", rank: 1)
            ],
            scenario: .buy,
            prompt: "Stress shopping or real replacement?",
            mode: .quick
        )

        XCTAssertEqual(assessment.need, .knowledge)
        XCTAssertGreaterThanOrEqual(assessment.promptTokenCount, 2)
        XCTAssertLessThanOrEqual(abs(assessment.topCandidateScore - assessment.secondCandidateScore), 1)
    }
}
