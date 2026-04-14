import XCTest
import BASHostKit
@testable import Before

final class BeforeProductCompatibilityTests: XCTestCase {
    func testLegacyIdentifiersNormalizeIntoGenericSubstrateVocabulary() {
        XCTAssertEqual(
            BeforeLegacyMigration.normalizedBrainStateUpdateSourceIdentifier("sessionPrime"),
            BeforeLegacyMigration.sessionBootstrapIdentifier
        )
        XCTAssertEqual(
            BeforeLegacyMigration.normalizedEntryIntentKindIdentifier("quickCapture"),
            "capture"
        )
        XCTAssertEqual(
            BeforeLegacyMigration.normalizedEntryIntentKindIdentifier("openMode"),
            "present"
        )
        XCTAssertEqual(
            BeforeLegacyMigration.normalizedEntryIntentKindIdentifier("openEvolutionControl"),
            "resume"
        )
        XCTAssertEqual(
            BeforeLegacyMigration.normalizedMemorySourceIdentifier("history"),
            BASMemorySource.archive.rawValue
        )
        XCTAssertEqual(
            BeforeLegacyMigration.normalizedMemorySourceIdentifier("reminder"),
            BASMemorySource.cue.rawValue
        )
    }

    func testHostCompatibilityOwnsSubstrateTranslation() {
        XCTAssertEqual(
            BeforeProductCompatibility.substrateEntryIntentKindID(rawValue: "reopenTomorrowItem"),
            "reopen"
        )
        XCTAssertEqual(
            BeforeProductCompatibility.substrateEntryIntentKindID(rawValue: "resumeCurrentDecision"),
            "resume"
        )
        XCTAssertEqual(
            BeforeProductCompatibility.substrateEntryIntentKindID(rawValue: "openEvolutionControl"),
            "resume"
        )
        XCTAssertEqual(DecisionMemorySource.history.basSource, .archive)
        XCTAssertEqual(DecisionMemorySource.reminder.basSource, .cue)
        XCTAssertEqual(DecisionMemorySource(.archive), .history)
        XCTAssertEqual(DecisionMemorySource(.cue), .reminder)
        XCTAssertEqual(BeforeProductCompatibility.substrateModeID(rawValue: "quick"), BASDecisionMode.primaryID)
        XCTAssertEqual(BeforeProductCompatibility.substrateModeID(rawValue: "balance"), BASDecisionMode.comparativeID)
        XCTAssertEqual(BeforeProductCompatibility.substrateModeID(rawValue: "mirror"), BASDecisionMode.reflectiveID)
        XCTAssertEqual(BeforeProductCompatibility.hostModeID(rawValue: BASDecisionMode.primaryID), "quick")
        XCTAssertEqual(BeforeProductCompatibility.hostModeID(rawValue: BASDecisionMode.comparativeID), "balance")
        XCTAssertEqual(BeforeProductCompatibility.hostModeID(rawValue: BASDecisionMode.reflectiveID), "mirror")
    }

    func testBeforeHostRuntimeCarriesBeforeSpecificFailureGuards() throws {
        let runtime = BeforeProductCompatibility.makeHostRuntime()

        let result = try runtime.startSession(
            BASHostSessionRequest(
                kind: .notification,
                workflowProfile: .primary,
                surface: .notification,
                prompt: "Should I send this tonight?",
                title: "Should I send this tonight?",
                riskLevel: .high,
                triggerReason: "prediction"
            ),
            now: Date(timeIntervalSince1970: 1_744_321_300)
        )

        XCTAssertGreaterThan(result.currentBrain.failureGuardCount, 0)
        XCTAssertTrue(result.currentBrain.activeConstraints.contains("high-risk-confirmation"))
    }

    func testCompatibilityCentralizesBeforeOwnedSemantics() {
        XCTAssertTrue(
            BeforeProductCompatibility.executionProfileBehavior.lowMemoryDetail().contains("iPhone 14")
        )
        XCTAssertTrue(
            BeforeProductCompatibility.referencePromptBehavior.presentationBehavior.sharedPrelude.contains("Before")
        )
        XCTAssertEqual(
            BeforeProductCompatibility.memoryDerivationBehavior.lateSessionPattern?.id,
            "semantic.pattern.late_night"
        )
    }
}
