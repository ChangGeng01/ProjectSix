import Testing
@testable import BASAppleAdapters

struct BASAppleReflectionAdaptationTests {
    @Test("reward treats regretful outcomes as negative and steady outcomes as positive")
    func rewardSemantics() {
        #expect(BASAppleReflectionAdaptationAdvisor.reward(outcomeID: "betterThanExpected"))
        #expect(BASAppleReflectionAdaptationAdvisor.reward(outcomeID: "okay"))
        #expect(BASAppleReflectionAdaptationAdvisor.reward(outcomeID: "notNeeded"))
        #expect(BASAppleReflectionAdaptationAdvisor.reward(outcomeID: "regrettedIt") == false)
        #expect(BASAppleReflectionAdaptationAdvisor.reward(outcomeID: "feltEmptier") == false)
    }

    @Test("chosen arm groups fast interrupts, slow exits, and permissive nudges")
    func chosenArmSemantics() {
        #expect(BASAppleReflectionAdaptationAdvisor.chosenArmID(finalActionID: "wait90s") == "tomorrow_box_interrupt")
        #expect(BASAppleReflectionAdaptationAdvisor.chosenArmID(finalActionID: "decideTomorrow") == "tomorrow_box_interrupt")
        #expect(BASAppleReflectionAdaptationAdvisor.chosenArmID(finalActionID: "leaveStimulus") == "slow_delay_guard")
        #expect(BASAppleReflectionAdaptationAdvisor.chosenArmID(finalActionID: "goAheadAnyway") == "brief_warm_nudge")
        #expect(BASAppleReflectionAdaptationAdvisor.chosenArmID(finalActionID: "continueMindfully") == "brief_warm_nudge")
    }

    @Test("risk level escalates bad outcomes and keeps interrupted actions low risk")
    func riskSemantics() {
        #expect(BASAppleReflectionAdaptationAdvisor.riskLevel(finalActionID: "goAheadAnyway", outcomeID: "regrettedIt") == .high)
        #expect(BASAppleReflectionAdaptationAdvisor.riskLevel(finalActionID: "continueMindfully", outcomeID: "okay") == .medium)
        #expect(BASAppleReflectionAdaptationAdvisor.riskLevel(finalActionID: "wait90s", outcomeID: "notNeeded") == .low)
        #expect(BASAppleReflectionAdaptationAdvisor.riskLevel(finalActionID: "leaveStimulus", outcomeID: "betterThanExpected") == .low)
        #expect(BASAppleReflectionAdaptationAdvisor.riskLevel(finalActionID: "goAheadAnyway", outcomeID: "betterThanExpected") == .medium)
    }
}
