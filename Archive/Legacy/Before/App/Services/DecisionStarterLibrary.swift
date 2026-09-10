import Foundation

struct DecisionStarterPrompt: Identifiable, Equatable, Sendable {
    let mode: DecisionMode
    let title: String
    let prompt: String

    var id: String { "\(mode.rawValue)-\(title)" }
}

enum DecisionStarterLibrary {
    static func suggestions(for mode: DecisionMode) -> [DecisionStarterPrompt] {
        switch mode {
        case .quick:
            [
                DecisionStarterPrompt(mode: .quick, title: "Buy now or wait?", prompt: "Do I buy this now or wait until tomorrow?"),
                DecisionStarterPrompt(mode: .quick, title: "Reply or pause?", prompt: "Do I reply to this message right now or pause first?"),
                DecisionStarterPrompt(mode: .quick, title: "Keep scrolling?", prompt: "Do I keep scrolling tonight or stop here?")
            ]
        case .balance:
            [
                DecisionStarterPrompt(mode: .balance, title: "Which option fits?", prompt: "Which option fits this week better?"),
                DecisionStarterPrompt(mode: .balance, title: "Take the plan?", prompt: "Should I say yes to this plan?"),
                DecisionStarterPrompt(mode: .balance, title: "Is the spend worth it?", prompt: "Is this spend worth it for me right now?")
            ]
        case .mirror:
            [
                DecisionStarterPrompt(mode: .mirror, title: "Stay or leave?", prompt: "Should I stay in this or leave?"),
                DecisionStarterPrompt(mode: .mirror, title: "Keep this role?", prompt: "Should I keep this role or start leaving it?"),
                DecisionStarterPrompt(mode: .mirror, title: "Repair or step back?", prompt: "Am I trying to repair this, or do I need to step back?")
            ]
        }
    }

    static var homeFeatured: [DecisionStarterPrompt] {
        [
            suggestions(for: .quick)[0],
            suggestions(for: .balance)[0],
            suggestions(for: .mirror)[0]
        ]
    }
}
