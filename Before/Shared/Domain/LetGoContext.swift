import Foundation

struct LetGoContext: Identifiable, Equatable, Sendable {
    let id: UUID
    let mode: DecisionMode
    let eyebrow: String
    let title: String
    let subtitle: String
    let itemTitle: String
    let itemDetail: String
    let instructionTitle: String
    let instructionDetail: String
    let completionTitle: String
    let completionSubtitle: String
    let primaryActionTitle: String
    let primaryTarget: AppTab
    let secondaryActionTitle: String?
    let secondaryTarget: AppTab?

    init(
        id: UUID = UUID(),
        mode: DecisionMode,
        eyebrow: String,
        title: String,
        subtitle: String,
        itemTitle: String,
        itemDetail: String,
        instructionTitle: String,
        instructionDetail: String,
        completionTitle: String,
        completionSubtitle: String,
        primaryActionTitle: String,
        primaryTarget: AppTab,
        secondaryActionTitle: String? = nil,
        secondaryTarget: AppTab? = nil
    ) {
        self.id = id
        self.mode = mode
        self.eyebrow = eyebrow
        self.title = title
        self.subtitle = subtitle
        self.itemTitle = itemTitle
        self.itemDetail = itemDetail
        self.instructionTitle = instructionTitle
        self.instructionDetail = instructionDetail
        self.completionTitle = completionTitle
        self.completionSubtitle = completionSubtitle
        self.primaryActionTitle = primaryActionTitle
        self.primaryTarget = primaryTarget
        self.secondaryActionTitle = secondaryActionTitle
        self.secondaryTarget = secondaryTarget
    }
}

enum LetGoFlickDirection: String, Equatable, Sendable {
    case left
    case right
}

struct LetGoMotionSample: Equatable, Sendable {
    let x: Double
    let y: Double
    let z: Double
    let timestamp: TimeInterval
}
