import Foundation

@MainActor
final class SupportInboxStore: ObservableObject {
    @Published private(set) var requests: [SupportRequest]

    init(seed: Bool = true) {
        requests = seed ? Self.seededRequests : []
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
        let request = SupportRequest(kind: kind, message: message)
        requests.insert(request, at: 0)
    }

    func reply(to requestID: UUID, with message: String) {
        guard let index = requests.firstIndex(where: { $0.id == requestID }) else { return }
        requests[index].addReply(message)
    }

    func markHeard(_ requestID: UUID) {
        guard let index = requests.firstIndex(where: { $0.id == requestID }) else { return }
        requests[index].markHeard()
    }

    func archive(_ requestID: UUID) {
        guard let index = requests.firstIndex(where: { $0.id == requestID }) else { return }
        requests[index].archive()
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
