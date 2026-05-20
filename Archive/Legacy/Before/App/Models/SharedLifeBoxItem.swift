import Foundation

enum SharedLifeBoxStatus: String, CaseIterable, Codable, Identifiable, Sendable {
    case pending
    case reviewing
    case approved
    case deferred
    case dropped

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pending: "Pending"
        case .reviewing: "Reviewing"
        case .approved: "Approved"
        case .deferred: "Deferred"
        case .dropped: "Dropped"
        }
    }
}

struct SharedLifeBoxItem: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let createdAt: Date
    var updatedAt: Date
    var title: String
    var detail: String
    var status: SharedLifeBoxStatus
    var modeRaw: String?
    var prompt: String
    var draftPayload: Data?
    var isSeeded: Bool

    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        updatedAt: Date = .now,
        title: String,
        detail: String,
        status: SharedLifeBoxStatus = .pending,
        mode: DecisionMode? = nil,
        prompt: String = "",
        draft: TomorrowBoxDraft? = nil,
        isSeeded: Bool = false
    ) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.title = title
        self.detail = detail
        self.status = status
        self.modeRaw = mode?.rawValue
        self.prompt = prompt
        self.draftPayload = draft.flatMap { try? JSONEncoder().encode($0) }
        self.isSeeded = isSeeded
    }

    var mode: DecisionMode? {
        modeRaw.flatMap(DecisionMode.init(rawValue:))
    }

    var draft: TomorrowBoxDraft? {
        guard let draftPayload else { return nil }
        return try? JSONDecoder().decode(TomorrowBoxDraft.self, from: draftPayload)
    }

    var canReopen: Bool {
        mode != nil && draft != nil
    }
}
