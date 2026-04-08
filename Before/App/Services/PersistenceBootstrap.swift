import Foundation
import SwiftData

struct PersistenceBootstrap {
    let container: ModelContainer
    let recoveryMessage: String?

    static func loadAppContainer() -> PersistenceBootstrap {
        do {
            let container = try ModelContainer(
                for: CheckEvent.self,
                SelfReminder.self,
                BalanceDecisionRecord.self,
                MirrorDecisionRecord.self,
                DecisionMemoryRecord.self,
                DecisionMemoryCandidateRecord.self,
                TomorrowBoxItem.self
            )
            return PersistenceBootstrap(container: container, recoveryMessage: nil)
        } catch {
            let fallbackConfiguration = ModelConfiguration(isStoredInMemoryOnly: true)

            guard let fallbackContainer = try? ModelContainer(
                for: CheckEvent.self,
                SelfReminder.self,
                BalanceDecisionRecord.self,
                MirrorDecisionRecord.self,
                DecisionMemoryRecord.self,
                DecisionMemoryCandidateRecord.self,
                TomorrowBoxItem.self,
                configurations: fallbackConfiguration
            ) else {
                fatalError("Unable to create a fallback SwiftData container: \(error.localizedDescription)")
            }

            return PersistenceBootstrap(
                container: fallbackContainer,
                recoveryMessage: "Stored data could not be opened, so Before is running in temporary recovery mode."
            )
        }
    }
}
