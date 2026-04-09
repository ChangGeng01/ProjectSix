import Foundation

@MainActor
final class SupportInboxStore: ObservableObject {
    @Published private(set) var requests: [SupportRequest]
    private let storage: CodableStateStorage
    private let key: String
    private let seed: Bool

    init(
        storage: CodableStateStorage = .protectedLocal,
        key: String = "before.support.inbox",
        seed: Bool = true
    ) {
        self.storage = storage
        self.key = key
        self.seed = seed
        self.requests = storage.load([SupportRequest].self, key: key) ?? (seed ? Self.seededRequests : [])
    }

    var activeRequests: [SupportRequest] {
        requests
            .filter { $0.status != .archived }
            .sorted { $0.createdAt > $1.createdAt }
    }

    var pendingCount: Int {
        requests.filter { $0.status == .pending }.count
    }

    var heardCount: Int {
        requests.filter { $0.status == .heard }.count
    }

    var archivedCount: Int {
        requests.filter { $0.status == .archived }.count
    }

    func create(kind: SupportRequestKind, message: String = "") {
        insert(SupportRequest(kind: kind, message: message))
    }

    func insert(_ request: SupportRequest) {
        requests.removeAll { $0.id == request.id }
        requests.insert(request, at: 0)
        persist()
    }

    func reply(to requestID: UUID, with message: String) {
        guard let index = requests.firstIndex(where: { $0.id == requestID }) else { return }
        requests[index].addReply(message)
        persist()
    }

    func markHeard(_ requestID: UUID) {
        guard let index = requests.firstIndex(where: { $0.id == requestID }) else { return }
        requests[index].markHeard()
        persist()
    }

    func archive(_ requestID: UUID) {
        guard let index = requests.firstIndex(where: { $0.id == requestID }) else { return }
        requests[index].archive()
        persist()
    }

    func clearAll() {
        requests = seed ? Self.seededRequests : []
        persist()
    }

    private func persist() {
        storage.save(requests, key: key)
    }

    private static let seededRequests: [SupportRequest] = [
        SupportRequest(
            createdAt: Date(timeIntervalSinceNow: -2_100),
            updatedAt: Date(timeIntervalSinceNow: -1_800),
            kind: .holdMe10Minutes,
            message: "I am trying not to tap through a decision too fast.",
            reply: "Stay with the pause for ten minutes.",
            status: .heard,
            isSeeded: true
        ),
        SupportRequest(
            createdAt: Date(timeIntervalSinceNow: -5_400),
            updatedAt: Date(timeIntervalSinceNow: -5_200),
            kind: .helpMeJudgeThis,
            message: "Help me compare this without spiralling.",
            reply: nil,
            status: .pending,
            isSeeded: true
        ),
        SupportRequest(
            createdAt: Date(timeIntervalSinceNow: -8_100),
            updatedAt: Date(timeIntervalSinceNow: -8_050),
            kind: .iAmGettingBlurry,
            message: "I am losing the shape of what I want here.",
            reply: "Lower the noise, then name the real question.",
            status: .archived,
            isSeeded: true
        )
    ]
}
