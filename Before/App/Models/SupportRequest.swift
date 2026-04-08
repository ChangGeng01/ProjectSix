import Foundation

enum SupportRequestStatus: String, CaseIterable, Codable, Identifiable, Sendable {
    case draft
    case pending
    case heard
    case archived

    var id: String { rawValue }

    var title: String {
        switch self {
        case .draft: "Draft"
        case .pending: "Pending"
        case .heard: "Heard"
        case .archived: "Archived"
        }
    }
}

struct SupportRequest: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let createdAt: Date
    var updatedAt: Date
    var kind: SupportRequestKind
    var message: String
    var reply: String?
    var status: SupportRequestStatus
    var modeRaw: String?
    var draftPayload: Data?
    var isSeeded: Bool

    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        updatedAt: Date = .now,
        kind: SupportRequestKind,
        message: String,
        reply: String? = nil,
        status: SupportRequestStatus = .pending,
        mode: DecisionMode? = nil,
        draft: TomorrowBoxDraft? = nil,
        isSeeded: Bool = false
    ) {
        let normalizedMessage = Self.trimmed(message)
        let normalizedReply = reply.flatMap { Self.trimmed($0).isEmpty ? nil : Self.trimmed($0) }

        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.kind = kind
        self.message = normalizedMessage.isEmpty ? kind.defaultMessage : normalizedMessage
        self.reply = normalizedReply
        self.status = status
        self.modeRaw = mode?.rawValue
        self.draftPayload = draft.flatMap { try? JSONEncoder().encode($0) }
        self.isSeeded = isSeeded
    }

    var summary: String {
        reply ?? kind.defaultMessage
    }

    var mode: DecisionMode? {
        modeRaw.flatMap(DecisionMode.init(rawValue:))
    }

    var draft: TomorrowBoxDraft? {
        guard let draftPayload else { return nil }
        return try? JSONDecoder().decode(TomorrowBoxDraft.self, from: draftPayload)
    }

    var canContinueDecision: Bool {
        mode != nil && draft != nil
    }

    var timestampLabel: String {
        status == .pending ? "Waiting" : "Updated"
    }

    mutating func addReply(_ reply: String) {
        let trimmedReply = Self.trimmed(reply)
        guard !trimmedReply.isEmpty else { return }
        self.reply = trimmedReply
        self.status = .heard
        self.updatedAt = .now
    }

    mutating func markHeard() {
        status = .heard
        updatedAt = .now
    }

    mutating func archive() {
        status = .archived
        updatedAt = .now
    }

    private static func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
