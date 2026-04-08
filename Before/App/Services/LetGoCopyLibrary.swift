import Foundation

enum LetGoCopyLibrary {
    static func tomorrowBoxContext(
        for item: TomorrowBoxItem,
        primaryTarget: AppTab = .home,
        secondaryTarget: AppTab = .box
    ) -> LetGoContext {
        switch item.mode {
        case .quick:
            LetGoContext(
                mode: .quick,
                eyebrow: "Tomorrow Box",
                title: "This can wait.",
                subtitle: "You already pulled it out of the impulse lane. Give yourself a cleaner exit too.",
                itemTitle: item.title,
                itemDetail: item.detail,
                instructionTitle: "Flick the phone gently",
                instructionDetail: "A short wrist flick is enough. This is just the moment you stop holding it in the foreground.",
                completionTitle: "Okay. Leave it there for now.",
                completionSubtitle: "You do not need to keep reacting to it tonight.",
                primaryActionTitle: "Back home",
                primaryTarget: primaryTarget,
                secondaryActionTitle: "Open Tomorrow Box",
                secondaryTarget: secondaryTarget
            )
        case .balance:
            LetGoContext(
                mode: .balance,
                eyebrow: "Tomorrow Box",
                title: "This does not need more weighing tonight.",
                subtitle: "The trade-off is stored with its context. You can reopen it when your head has more daylight.",
                itemTitle: item.title,
                itemDetail: item.detail,
                instructionTitle: "Flick the phone gently",
                instructionDetail: "Use one light wrist flick to let the decision leave the front of your mind for now.",
                completionTitle: "Okay. Stop carrying it for now.",
                completionSubtitle: "The choice is still there, but it no longer needs the rest of this hour.",
                primaryActionTitle: "Back home",
                primaryTarget: primaryTarget,
                secondaryActionTitle: "Open Tomorrow Box",
                secondaryTarget: secondaryTarget
            )
        case .mirror:
            LetGoContext(
                mode: .mirror,
                eyebrow: "Tomorrow Box",
                title: "You saw enough for today.",
                subtitle: "The heavier question is saved. You do not need to keep staring at it to prove it matters.",
                itemTitle: item.title,
                itemDetail: item.detail,
                instructionTitle: "Flick the phone gently",
                instructionDetail: "A short wrist flick is enough. Let the question step out of the foreground for tonight.",
                completionTitle: "Okay. That is enough for today.",
                completionSubtitle: "The question is still there, but it does not need the rest of your evening.",
                primaryActionTitle: "Back home",
                primaryTarget: primaryTarget,
                secondaryActionTitle: "Open Tomorrow Box",
                secondaryTarget: secondaryTarget
            )
        }
    }
}
