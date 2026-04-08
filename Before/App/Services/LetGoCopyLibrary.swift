import Foundation

enum LetGoCopyLibrary {
    @MainActor
    static func quickStepAwayContext(
        for session: QuickCheckSession,
        result: QuickCheckResult,
        primaryTarget: AppTab = .home,
        secondaryTarget: AppTab = .history
    ) -> LetGoContext {
        LetGoContext(
            mode: .quick,
            eyebrow: "Step away first",
            title: "Leave the trigger before you decide anything else.",
            subtitle: "You already chose not to stay inside the same blur. Give yourself a cleaner break from it too.",
            itemTitle: session.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? session.scenario.title
                : session.note.trimmingCharacters(in: .whitespacesAndNewlines),
            itemDetail: result.afterPerspective,
            instructionTitle: "Flick the phone gently",
            instructionDetail: "A short wrist flick is enough. This is just the moment you stop negotiating with it from the same place.",
            completionTitle: "Okay. Step out first.",
            completionSubtitle: "You do not need to keep this in front of you while your state is still hot.",
            settledTitle: "Out of the trigger lane",
            settledDetail: "Take a step away, then come back only if the choice still feels clean.",
            primaryActionTitle: "Back home",
            primaryTarget: primaryTarget,
            secondaryActionTitle: "Open History",
            secondaryTarget: secondaryTarget
        )
    }

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
                settledTitle: "Out of the foreground",
                settledDetail: "You can leave this in Tomorrow Box and come back when timing is cleaner.",
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
                settledTitle: "Stored with context",
                settledDetail: "The trade-off is in Tomorrow Box now, so you do not need to keep balancing it tonight.",
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
                settledTitle: "Held, but no longer staring back",
                settledDetail: "The heavier question is in Tomorrow Box, with enough structure to revisit later.",
                primaryActionTitle: "Back home",
                primaryTarget: primaryTarget,
                secondaryActionTitle: "Open Tomorrow Box",
                secondaryTarget: secondaryTarget
            )
        }
    }

    static func savedBalanceContext(
        for record: BalanceDecisionRecord,
        primaryTarget: AppTab = .home,
        secondaryTarget: AppTab = .history
    ) -> LetGoContext {
        LetGoContext(
            mode: .balance,
            eyebrow: "Balance saved",
            title: "That board can rest now.",
            subtitle: "You already pulled the trade-off apart. You do not need to keep re-weighing it tonight.",
            itemTitle: record.prompt,
            itemDetail: record.focusSummary,
            instructionTitle: "Flick the phone gently",
            instructionDetail: "Use one light wrist flick to let the board leave the front of your mind for now.",
            completionTitle: "Okay. The board is saved.",
            completionSubtitle: "You can come back when you want more clarity, not just more spin.",
            settledTitle: "Saved and set down",
            settledDetail: "The balance board is in History now, so you can stop carrying the trade-off for a bit.",
            primaryActionTitle: "Back home",
            primaryTarget: primaryTarget,
            secondaryActionTitle: "Open History",
            secondaryTarget: secondaryTarget
        )
    }

    static func savedMirrorContext(
        for record: MirrorDecisionRecord,
        primaryTarget: AppTab = .home,
        secondaryTarget: AppTab = .history
    ) -> LetGoContext {
        LetGoContext(
            mode: .mirror,
            eyebrow: "Mirror saved",
            title: "You have seen enough for now.",
            subtitle: "The reflection is saved. You do not need to keep looking at it to prove it matters.",
            itemTitle: record.prompt,
            itemDetail: record.coreTension,
            instructionTitle: "Flick the phone gently",
            instructionDetail: "A short wrist flick is enough. Let the mirror step out of the foreground for tonight.",
            completionTitle: "Okay. That is enough for today.",
            completionSubtitle: "The mirror is still there, but it does not need the rest of your night.",
            settledTitle: "Saved without staying open",
            settledDetail: "The mirror is in History now, with enough shape to reopen when you want to look again.",
            primaryActionTitle: "Back home",
            primaryTarget: primaryTarget,
            secondaryActionTitle: "Open History",
            secondaryTarget: secondaryTarget
        )
    }
}
